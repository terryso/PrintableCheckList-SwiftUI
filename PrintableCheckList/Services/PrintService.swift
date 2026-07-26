import UIKit

/// Everything the system print panel needs. It carries the finished PDF rather
/// than a formatter so the printed sheet is the file the user previewed and can
/// export.
struct ChecklistPrintJob {
    let printInfo: UIPrintInfo
    let pdfData: Data
}

@MainActor
enum PrintService {
    static func printJob(for document: PrintReadyDocument) throws -> ChecklistPrintJob {
        try document.verifyFitsWithinThePageLimit()

        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = document.project.title
        printInfo.duplex = .none
        printInfo.orientation = .portrait
        return ChecklistPrintJob(printInfo: printInfo, pdfData: document.data)
    }

    static func present(
        document: PrintReadyDocument,
        completion: @escaping (Bool) -> Void = { _ in }
    ) throws {
        let job = try printJob(for: document)

        guard UIPrintInteractionController.isPrintingAvailable else {
            completion(false)
            return
        }

        let controller = UIPrintInteractionController.shared
        controller.printInfo = job.printInfo
        controller.showsPageRange = false
        controller.printingItem = job.pdfData

        let completionHandler: UIPrintInteractionController.CompletionHandler = {
            _, completed, error in
            completion(completed && error == nil)
        }

        if UIDevice.current.userInterfaceIdiom == .pad,
           let view = topViewController(from: rootViewController())?.view {
            let sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            controller.present(
                from: sourceRect,
                in: view,
                animated: true,
                completionHandler: completionHandler
            )
        } else {
            controller.present(
                animated: true,
                completionHandler: completionHandler
            )
        }
    }

    private static func topViewController(from root: UIViewController?) -> UIViewController? {
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = root as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        return root
    }

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
