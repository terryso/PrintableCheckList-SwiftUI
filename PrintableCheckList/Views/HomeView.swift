import SwiftUI

private enum AppRoute: Hashable {
    case items(UUID)
    case settings
}

struct HomeView: View {
    @EnvironmentObject private var store: ChecklistStore

    @State private var path: [AppRoute] = []
    @State private var editMode: EditMode = .inactive
    @State private var showsNewProject = false
    @State private var projectBeingEdited: ChecklistProject?
    @State private var pendingCreatedProjectID: UUID?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.projects.isEmpty {
                    emptyState
                } else {
                    projectList
                }
            }
            .navigationTitle(Text("Lists"))
            .toolbar {
                if !store.projects.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        OrganizeButton(
                            editMode: $editMode,
                            accessibilityIdentifier: "organizeListsButton"
                        )
                    }
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        showsNewProject = true
                    } label: {
                        Label("New List", systemImage: "plus")
                    }
                    .accessibilityHint(Text("Create a list and optionally add its first items"))
                    .accessibilityIdentifier("newListButton")

                    Spacer()

                    Button {
                        path.append(.settings)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("settingsButton")
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .items(let projectID):
                    ItemsView(projectID: projectID)
                case .settings:
                    SettingsView()
                }
            }
        }
        .sheet(
            isPresented: $showsNewProject,
            onDismiss: openPendingProject
        ) {
            NewProjectSheet { title, itemsText in
                pendingCreatedProjectID = store.addProject(
                    title: title,
                    itemsText: itemsText
                )
            }
        }
        .sheet(item: $projectBeingEdited) { project in
            SingleLineEditorSheet(
                title: String(localized: "Edit List"),
                fieldLabel: String(localized: "List Name"),
                initialText: project.title,
                placeholder: String(localized: "Example: Travel Checklist")
            ) { text in
                store.renameProject(id: project.id, title: text)
            }
        }
        .alert(
            Text("Unable to save changes"),
            isPresented: Binding(
                get: { store.persistenceError != nil },
                set: { isPresented in
                    if !isPresented {
                        store.clearPersistenceError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.persistenceError ?? "")
        }
    }

    private var projectList: some View {
        List {
            ForEach(store.projects) { project in
                NavigationLink(value: AppRoute.items(project.id)) {
                    ProjectRow(project: project)
                }
                .accessibilityHint(Text("Open List"))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.deleteProject(id: project.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        projectBeingEdited = project
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button {
                        projectBeingEdited = project
                    } label: {
                        Label("Edit List", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        store.deleteProject(id: project.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: store.deleteProjects)
            .onMove(perform: store.moveProjects)
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Lists Yet", systemImage: "list.bullet.clipboard")
        } description: {
            Text("Start by creating a list you can preview and print.")
        } actions: {
            Button {
                showsNewProject = true
            } label: {
                Label("Create Your First List", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("emptyCreateListButton")
        }
    }

    private func openPendingProject() {
        guard let projectID = pendingCreatedProjectID else { return }
        pendingCreatedProjectID = nil
        path.append(.items(projectID))
    }
}
