import SwiftUI

struct ProPaywallView: View {
    @EnvironmentObject private var proEntitlement: ProEntitlementStore

    var body: some View {
        ContentUnavailableView {
            Label("Unlock Pro to Use AI", systemImage: "sparkles")
        } description: {
            Text(
                "Pro is a one-time purchase. It includes up to 20 managed AI operations per calendar month and use of your own API Key."
            )
        } actions: {
            VStack(spacing: 12) {
                Button(proEntitlement.purchaseButtonTitle) {
                    Task {
                        await proEntitlement.purchase()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!proEntitlement.canPurchase)
                .accessibilityIdentifier("unlockProButton")

                Button("Restore Purchases") {
                    Task {
                        await proEntitlement.restorePurchases()
                    }
                }
                .disabled(proEntitlement.isWorking)
                .accessibilityIdentifier("restoreProPurchasesButton")

                if proEntitlement.status == .loading || proEntitlement.isWorking {
                    ProgressView()
                }

                if let statusMessage = proEntitlement.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .accessibilityIdentifier("proPaywallView")
    }
}
