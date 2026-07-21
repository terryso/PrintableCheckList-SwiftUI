import SwiftUI

private enum AppRoute: Hashable {
    case items(UUID)
    case settings
}

struct HomeView: View {
    @EnvironmentObject private var store: ChecklistStore

    @State private var path: [AppRoute] = []
    @State private var showsNewProject = false
    @State private var projectBeingEdited: ChecklistProject?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(store.projects) { project in
                    ProjectRow(
                        project: project,
                        onOpen: { path.append(.items(project.id)) },
                        onEdit: { projectBeingEdited = project }
                    )
                }
                .onDelete(perform: store.deleteProjects)
                .onMove(perform: store.moveProjects)
            }
            .listStyle(.plain)
            .navigationTitle(Text("Lists"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        showsNewProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("New List"))

                    Spacer()

                    Button {
                        path.append(.settings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(Text("Settings"))
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
        .sheet(isPresented: $showsNewProject) {
            TextEditorSheet(title: String(localized: "New List")) { text in
                store.addProject(title: text)
            }
        }
        .sheet(item: $projectBeingEdited) { project in
            TextEditorSheet(
                title: String(localized: "Edit List"),
                initialText: project.title
            ) { text in
                store.renameProject(id: project.id, title: text)
            }
        }
        .alert(
            Text("Help Improve Flash"),
            isPresented: Binding(
                get: { store.shouldRequestDeveloperAnalyticsConsent },
                set: { _ in }
            )
        ) {
            Button("Not Now", role: .cancel) {
                Task {
                    await store.setDeveloperAnalyticsEnabled(false)
                }
            }
            Button("Share Data") {
                Task {
                    await store.setDeveloperAnalyticsEnabled(true)
                }
            }
        } message: {
            Text(
                "With your permission, Flash sends your checklist text and an anonymous installation identifier to the developer to understand how the app is used. You can change this later in Settings."
            )
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
}
