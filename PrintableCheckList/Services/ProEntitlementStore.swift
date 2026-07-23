import Combine
import Foundation
import StoreKit

enum ProEntitlementStatus: Equatable {
    case loading
    case notEntitled
    case entitled
    case unavailable
}

enum ProEntitlementError: LocalizedError, Equatable {
    case notEntitled
    case unverifiedTransaction

    var errorDescription: String? {
        switch self {
        case .notEntitled:
            String(localized: "Unlock Pro before starting an AI operation.")
        case .unverifiedTransaction:
            String(localized: "The Pro purchase could not be verified.")
        }
    }
}

@MainActor
final class ProEntitlementStore: ObservableObject {
    static let productID = "com.wehack.PrintableCheckList.pro"

    @Published private(set) var status: ProEntitlementStatus = .loading
    @Published private(set) var product: Product?
    @Published private(set) var isWorking = false
    @Published private(set) var statusMessage: String?

    private let productID: String
    private let entitlementOverride: Bool?
    private var transactionUpdatesTask: Task<Void, Never>?

    init(
        productID: String = ProEntitlementStore.productID,
        entitlementOverride: Bool? = nil
    ) {
        self.productID = productID
        self.entitlementOverride = entitlementOverride
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var isEntitled: Bool {
        status == .entitled
    }

    var canPurchase: Bool {
        product != nil && !isWorking && entitlementOverride == nil
    }

    var purchaseButtonTitle: String {
        guard let price = product?.displayPrice else {
            return String(localized: "Unlock Pro")
        }
        return String.localizedStringWithFormat(
            String(localized: "Unlock Pro (%@)"),
            price
        )
    }

    func start() {
        guard transactionUpdatesTask == nil else { return }

        if let entitlementOverride {
            status = entitlementOverride ? .entitled : .notEntitled
            statusMessage = nil
            return
        }

        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update,
                   transaction.productID == self.productID
                {
                    await transaction.finish()
                }
                await self.refresh()
            }
        }

        Task {
            await refresh()
        }
    }

    func refresh() async {
        if let entitlementOverride {
            status = entitlementOverride ? .entitled : .notEntitled
            statusMessage = nil
            return
        }

        status = .loading
        do {
            let entitlement = try await currentVerifiedEntitlement()
            status = entitlement == nil ? .notEntitled : .entitled
        } catch {
            status = .unavailable
            statusMessage = String(localized: "Unable to check Pro purchase status. Please try again.")
            return
        }

        do {
            product = try await Product.products(for: [productID]).first
            statusMessage = product == nil
                ? String(localized: "The Pro purchase is not available from the App Store right now.")
                : nil
        } catch {
            product = nil
            statusMessage = isEntitled
                ? String(localized: "Pro is unlocked, but purchase options are temporarily unavailable.")
                : String(localized: "The Pro purchase is not available from the App Store right now.")
        }
    }

    func purchase() async {
        guard entitlementOverride == nil, !isWorking else { return }
        guard let product else {
            statusMessage = String(localized: "The Pro purchase is not available from the App Store right now.")
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try verifiedTransaction(from: verification)
                await transaction.finish()
                await refresh()
            case .userCancelled:
                statusMessage = nil
            case .pending:
                statusMessage = String(localized: "Your Pro purchase is pending approval.")
            @unknown default:
                statusMessage = String(localized: "The Pro purchase could not be completed. Please try again.")
            }
        } catch {
            statusMessage = String(localized: "The Pro purchase could not be completed. Please try again.")
        }
    }

    func restorePurchases() async {
        guard entitlementOverride == nil, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await AppStore.sync()
            await refresh()
            if !isEntitled {
                statusMessage = String(localized: "No Pro purchase was found for this Apple Account.")
            }
        } catch {
            statusMessage = String(localized: "Unable to restore purchases. Please try again.")
        }
    }

    func signedEntitlementJWS() async throws -> String {
        guard entitlementOverride == nil else {
            throw ProEntitlementError.notEntitled
        }
        guard let entitlement = try await currentVerifiedEntitlement() else {
            throw ProEntitlementError.notEntitled
        }
        return entitlement.jwsRepresentation
    }

    private func currentVerifiedEntitlement() async throws -> VerificationResult<Transaction>? {
        guard let entitlement = await Transaction.currentEntitlement(for: productID) else {
            return nil
        }
        let transaction = try verifiedTransaction(from: entitlement)
        guard transaction.revocationDate == nil else { return nil }
        return entitlement
    }

    private func verifiedTransaction(
        from verification: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch verification {
        case .verified(let transaction):
            transaction
        case .unverified:
            throw ProEntitlementError.unverifiedTransaction
        }
    }
}
