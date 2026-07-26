import PDFKit
import SwiftUI

/// Shows the print-ready PDF itself, so what the user sees is the file that
/// gets exported and printed.
struct PDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        apply(data, to: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        guard context.coordinator.renderedData != data else { return }
        apply(data, to: uiView, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var renderedData: Data?
    }

    private func apply(_ data: Data, to view: PDFView, coordinator: Coordinator) {
        coordinator.renderedData = data
        view.document = PDFDocument(data: data)
    }
}
