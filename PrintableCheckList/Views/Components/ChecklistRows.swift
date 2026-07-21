import SwiftUI

struct ProjectRow: View {
    let project: ChecklistProject
    let onOpen: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.title3)
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(project.title)
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(itemCountText)
                            .font(.system(size: 11))
                            .foregroundStyle(.primary)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Edit List"))
        }
        .frame(minHeight: 43)
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
            Image(systemName: "square")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(item.title)
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 43)
        .contentShape(Rectangle())
    }
}
