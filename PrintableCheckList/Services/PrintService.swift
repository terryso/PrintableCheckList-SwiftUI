import UIKit

enum PrintHTMLBuilder {
    static func html(for project: ChecklistProject) -> String {
        let rows = project.items.map { item in
            """
            <div class="item"><span class="checkbox"></span><span>\(escape(item.title))</span></div>
            """
        }.joined()

        return """
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { font-family: -apple-system, sans-serif; }
            h1 { font-size: 32px; }
            .item { min-height: 30px; font-size: 16px; line-height: 30px; padding-left: 35px; margin-bottom: 15px; }
            .checkbox { box-sizing: border-box; display: block; float: left; width: 20px; height: 20px; border: 2px solid black; margin: 5px 20px 0 0; }
          </style>
        </head>
        <body><h1>\(escape(project.title))</h1>\(rows)</body>
        </html>
        """
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

@MainActor
enum PrintService {
    static func present(project: ChecklistProject) {
        guard UIPrintInteractionController.isPrintingAvailable else {
            return
        }

        let controller = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = project.title
        printInfo.duplex = .none
        controller.printInfo = printInfo
        controller.showsPageRange = false

        let formatter = UIMarkupTextPrintFormatter(
            markupText: PrintHTMLBuilder.html(for: project)
        )
        formatter.contentInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        controller.printFormatter = formatter

        if UIDevice.current.userInterfaceIdiom == .pad,
           let view = topViewController(from: rootViewController())?.view {
            let sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            controller.present(from: sourceRect, in: view, animated: true)
        } else {
            controller.present(animated: true)
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
