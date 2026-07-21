import SwiftUI

struct PreviewView: View {
    let projectID: UUID

    @EnvironmentObject private var store: ChecklistStore
    @ScaledMetric(relativeTo: .body) private var checkboxSize = 20

    var body: some View {
        ScrollView {
            if let project = store.project(id: projectID) {
                VStack(alignment: .leading, spacing: 15) {
                    Text(project.title)
                        .font(.largeTitle.bold())
                        .padding(.bottom, 4)

                    ForEach(project.items) { item in
                        HStack(alignment: .top, spacing: 20) {
                            Rectangle()
                                .stroke(.black, lineWidth: 2)
                                .frame(width: checkboxSize, height: checkboxSize)
                                .padding(.top, 5)
                                .accessibilityHidden(true)

                            Text(item.title)
                                .font(.body)
                                .lineSpacing(7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.leading, 35)
                        .padding(.bottom, 15)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(.white)
        .foregroundStyle(.black)
        .navigationTitle(Text("Preview"))
        .toolbar {
            if let project = store.project(id: projectID) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        PrintService.present(project: project) { completed in
                            if completed {
                                store.markDeveloperAnalyticsConsentOpportunity()
                            }
                        }
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                    .accessibilityHint(Text("Open the system print options"))
                    .accessibilityIdentifier("previewPrintButton")
                }
            }
        }
        .developerAnalyticsConsentAlert()
    }
}
