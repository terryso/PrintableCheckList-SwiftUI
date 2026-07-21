import SwiftUI

struct ItemsView: View {
    let projectID: UUID

    @EnvironmentObject private var store: ChecklistStore
    @State private var showsNewItems = false
    @State private var itemBeingEdited: ChecklistItem?
    @State private var showsActions = false
    @State private var showsPreview = false

    var body: some View {
        Group {
            if let project = store.project(id: projectID) {
                List {
                    ForEach(project.items) { item in
                        Button {
                            itemBeingEdited = item
                        } label: {
                            ItemRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        store.deleteItems(projectID: projectID, at: offsets)
                    }
                    .onMove { offsets, destination in
                        store.moveItems(
                            projectID: projectID,
                            from: offsets,
                            to: destination
                        )
                    }
                }
                .listStyle(.plain)
                .navigationTitle(project.title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }

                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            showsNewItems = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(Text("New Item"))

                        Spacer()

                        Button {
                            showsActions = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel(Text("Actions"))
                    }
                }
                .confirmationDialog(
                    "",
                    isPresented: $showsActions,
                    titleVisibility: .hidden
                ) {
                    Button(String(localized: "Print")) {
                        PrintService.present(project: project)
                    }
                    Button(String(localized: "Preview")) {
                        showsPreview = true
                    }
                    Button(String(localized: "Cancel"), role: .cancel) {}
                }
                .navigationDestination(isPresented: $showsPreview) {
                    PreviewView(projectID: projectID)
                }
            } else {
                ContentUnavailableView(
                    String(localized: "List not found"),
                    systemImage: "list.bullet.clipboard"
                )
            }
        }
        .sheet(isPresented: $showsNewItems) {
            TextEditorSheet(
                title: String(localized: "New Item"),
                placeholder: String(localized: "One item per line")
            ) { text in
                store.addItems(projectID: projectID, text: text)
            }
        }
        .sheet(item: $itemBeingEdited) { item in
            TextEditorSheet(
                title: String(localized: "Edit Item"),
                initialText: item.title
            ) { text in
                store.renameItem(projectID: projectID, itemID: item.id, title: text)
            }
        }
    }
}
