import SwiftUI

struct ItemsView: View {
    let projectID: UUID

    @EnvironmentObject private var store: ChecklistStore
    @State private var editMode: EditMode = .inactive
    @State private var showsNewItems = false
    @State private var showsAIGeneration = false
    @State private var itemBeingEdited: ChecklistItem?
    @State private var showsPreview = false

    var body: some View {
        Group {
            if let project = store.project(id: projectID) {
                Group {
                    if project.items.isEmpty {
                        emptyState
                    } else {
                        itemList(project: project)
                    }
                }
                .environment(\.editMode, $editMode)
                .navigationTitle(project.title)
                .toolbar {
                    if !project.items.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            OrganizeButton(
                                editMode: $editMode,
                                accessibilityIdentifier: "organizeItemsButton"
                            )
                        }
                    }

                    ToolbarItemGroup(placement: .bottomBar) {
                        Menu {
                            Button {
                                showsNewItems = true
                            } label: {
                                Label("Add Manually", systemImage: "square.and.pencil")
                            }
                            .accessibilityIdentifier("manualAddItemsButton")

                            Button {
                                showsAIGeneration = true
                            } label: {
                                Label("Add with AI", systemImage: "sparkles")
                            }
                            .accessibilityIdentifier("aiAddItemsButton")
                        } label: {
                            toolbarLabel("Add", systemImage: "plus")
                        }
                        .accessibilityHint(Text("Add items manually or ask AI for suggestions"))
                        .accessibilityIdentifier("addItemsButton")

                        Spacer()

                        Button {
                            showsPreview = true
                        } label: {
                            toolbarLabel(
                                "Preview",
                                systemImage: "doc.text.magnifyingglass"
                            )
                        }
                        .accessibilityHint(Text("Preview the printable checklist"))
                        .accessibilityIdentifier("previewButton")

                        Spacer()

                        Button {
                            print(project)
                        } label: {
                            toolbarLabel("Print", systemImage: "printer")
                        }
                        .accessibilityHint(Text("Open the system print options"))
                        .accessibilityIdentifier("printButton")
                    }
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
            ItemsEditorSheet { text in
                store.addItems(projectID: projectID, text: text)
            }
        }
        .sheet(isPresented: $showsAIGeneration) {
            AIChecklistGenerationSheet(
                mode: .supplement,
                existingProject: store.project(id: projectID)
            ) { draft in
                store.addItems(
                    projectID: projectID,
                    text: draft.items.joined(separator: "\n")
                )
            }
        }
        .sheet(item: $itemBeingEdited) { item in
            SingleLineEditorSheet(
                title: String(localized: "Edit Item"),
                fieldLabel: String(localized: "Item"),
                initialText: item.title,
                placeholder: String(localized: "Item Name")
            ) { text in
                store.renameItem(
                    projectID: projectID,
                    itemID: item.id,
                    title: text
                )
            }
        }
        .developerAnalyticsConsentAlert()
    }

    private func itemList(project: ChecklistProject) -> some View {
        List {
            ForEach(project.items) { item in
                Button {
                    itemBeingEdited = item
                } label: {
                    ItemRow(item: item)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.title))
                .accessibilityHint(Text("Double-tap to edit this item"))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.deleteItem(projectID: projectID, itemID: item.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        itemBeingEdited = item
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button {
                        itemBeingEdited = item
                    } label: {
                        Label("Edit Item", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        store.deleteItem(projectID: projectID, itemID: item.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
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
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Items Yet", systemImage: "text.badge.plus")
        } description: {
            Text("Add your first items. You can enter one item per line.")
        } actions: {
            VStack(spacing: 12) {
                Button {
                    showsNewItems = true
                } label: {
                    Label("Add Manually", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("emptyAddItemsButton")

                Button {
                    showsAIGeneration = true
                } label: {
                    Label("Add with AI", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("emptyAIAddItemsButton")
            }
        }
    }

    private func print(_ project: ChecklistProject) {
        PrintService.present(project: project) { completed in
            if completed {
                store.markDeveloperAnalyticsConsentOpportunity()
            }
        }
    }

    private func toolbarLabel(
        _ title: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.subheadline.weight(.medium))
    }
}
