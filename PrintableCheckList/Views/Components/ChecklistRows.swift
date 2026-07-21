import SwiftUI

private struct DeveloperAnalyticsConsentAlertModifier: ViewModifier {
    @EnvironmentObject private var store: ChecklistStore

    func body(content: Content) -> some View {
        content.alert(
            Text("Share Checklist Data?"),
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
            Button("Agree and Turn On") {
                Task {
                    await store.setDeveloperAnalyticsEnabled(true)
                }
            }
        } message: {
            Text("Checklist Analytics Consent Message")
        }
    }
}

extension View {
    func developerAnalyticsConsentAlert() -> some View {
        modifier(DeveloperAnalyticsConsentAlertModifier())
    }
}

struct OrganizeButton: View {
    @Binding var editMode: EditMode
    let accessibilityIdentifier: String

    var body: some View {
        Button(editMode.isEditing ? "Done" : "Organize") {
            withAnimation {
                editMode = editMode.isEditing ? .inactive : .active
            }
        }
        .accessibilityHint(
            Text(editMode.isEditing ? "Finish organizing" : "Reorder and delete")
        )
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct ProjectRow: View {
    let project: ChecklistProject

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.bullet.clipboard")
                .font(.title3)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(itemCountText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var itemCountText: String {
        let count = project.items.count
        let key = count == 1 ? "%ld item" : "%ld items"
        return String.localizedStringWithFormat(
            NSLocalizedString(key, comment: "Number of items in a list"),
            count
        )
    }
}

struct ItemRow: View {
    let item: ChecklistItem

    var body: some View {
        HStack(spacing: 12) {
            Text(item.title)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
