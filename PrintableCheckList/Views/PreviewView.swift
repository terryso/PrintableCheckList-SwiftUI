import SwiftUI

struct PreviewView: View {
    let projectID: UUID

    @EnvironmentObject private var store: ChecklistStore
    @State private var paperSize: PaperSize = .default()
    @State private var document: PrintReadyDocument?
    @State private var exportedFile: ExportedPDF?
    @State private var actionError: String?

    var body: some View {
        Group {
            if let document {
                preview(document: document)
            } else if store.project(id: projectID) == nil {
                ContentUnavailableView(
                    String(localized: "List not found"),
                    systemImage: "list.bullet.clipboard"
                )
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(Text("Preview"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let document {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        export(document: document)
                    } label: {
                        Label("Export PDF", systemImage: "square.and.arrow.up")
                    }
                    .disabled(document.exceedsPageLimit)
                    .accessibilityHint(Text("Save or share the print-ready PDF"))
                    .accessibilityIdentifier("previewExportPDFButton")

                    Button {
                        print(document: document)
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                    .disabled(document.exceedsPageLimit)
                    .accessibilityHint(Text("Open the system print options"))
                    .accessibilityIdentifier("previewPrintButton")
                }
            }
        }
        .task(id: DocumentInput(project: store.project(id: projectID), paperSize: paperSize)) {
            document = store.project(id: projectID).map {
                PrintReadyDocument(project: $0, paperSize: paperSize)
            }
        }
        .sheet(item: $exportedFile, onDismiss: cleanupExportedFile) { file in
            ActivityView(activityItems: [file.url])
        }
        .alert(
            Text("Unable to Create PDF"),
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            ),
            presenting: actionError
        ) { _ in
            Button("Confirm", role: .cancel) { actionError = nil }
        } message: { message in
            Text(message)
        }
        .developerAnalyticsConsentAlert()
    }

    private func preview(document: PrintReadyDocument) -> some View {
        VStack(spacing: 0) {
            PDFPreview(data: document.data)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(document.accessibilityLabel))
                .accessibilityIdentifier("printablePDFView")

            Divider()
            controls(document: document)
        }
    }

    private func controls(document: PrintReadyDocument) -> some View {
        VStack(spacing: 10) {
            if document.exceedsPageLimit {
                Text(document.overflowDescription)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("printableOverflowNotice")
            }

            Picker(selection: $paperSize) {
                ForEach(PaperSize.allCases) { size in
                    Text(size.localizedName).tag(size)
                }
            } label: {
                Text("Paper Size")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("paperSizePicker")

            Text(document.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("printablePDFSummary")
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func export(document: PrintReadyDocument) {
        do {
            exportedFile = ExportedPDF(url: try document.writeToTemporaryFile())
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func cleanupExportedFile() {
        if let url = exportedFile?.url {
            try? FileManager.default.removeItem(at: url)
        }
        exportedFile = nil
    }

    private func print(document: PrintReadyDocument) {
        do {
            try PrintService.present(document: document) { systemPrintCompleted in
                // The system print panel only confirms it dismissed after
                // printing — that is `system_print_completed`, NOT print
                // success. Real `print_success` is the user later confirming
                // they produced and used paper. The funnel event itself is
                // emitted by the Beta analytics pipeline (see beta-spec §6).
                if systemPrintCompleted {
                    store.markDeveloperAnalyticsConsentOpportunity()
                }
            }
        } catch {
            actionError = error.localizedDescription
        }
    }
}

/// Rebuilding the PDF is only worth doing when the checklist or the paper
/// changes.
private struct DocumentInput: Equatable {
    let project: ChecklistProject?
    let paperSize: PaperSize
}

private struct ExportedPDF: Identifiable {
    let id = UUID()
    let url: URL
}
