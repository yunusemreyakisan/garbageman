import SwiftUI
import GarbagemanCore

struct CategoryDetailView: View {
    @ObservedObject var category: CategoryViewModel
    let isBusy: Bool
    let onScan: () -> Void
    let onToggleAll: () -> Void
    let onToggleTarget: (String) -> Void

    var body: some View {
        switch category.scanState {
        case .idle:
            EmptyStateView(
                icon: category.iconName,
                title: "Not scanned yet",
                message: "Run a scan to inspect \(category.displayName.lowercased()).",
                buttonTitle: "Scan",
                action: onScan
            )
        case .scanning:
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("Scanning \(category.displayName)…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .finished:
            if category.isUnavailable {
                EmptyStateView(
                    icon: "lock.shield",
                    title: category.displayName,
                    message: category.permissionMessage,
                    buttonTitle: nil,
                    action: nil
                )
            } else if category.groups.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "Nothing to clean here",
                    message: "This category has no reclaimable items right now.",
                    buttonTitle: nil,
                    action: nil
                )
            } else {
                detailList
            }
        }
    }

    private var detailList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(category.displayName)
                    .font(.title2.weight(.semibold))

                Text("\(humanBytes(category.totalBytes)) available across \(category.allTargets.count) item(s)")
                    .foregroundStyle(.secondary)

                HStack {
                    SelectionCheckbox(
                        state: category.checkboxState,
                        isEnabled: category.isSelectable && !isBusy,
                        action: onToggleAll
                    )
                    Text(category.checkboxState == .on ? "Clear selection" : "Select all")
                    Spacer()
                }
                .font(.callout)

                if let note = category.note, !note.isEmpty {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)

            Divider()

            HStack(spacing: 12) {
                Text("Name")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Size")
                    .frame(width: 92, alignment: .trailing)
                Text("Modified")
                    .frame(width: 140, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            List {
                ForEach(category.groups) { group in
                    Section {
                        ForEach(group.targets) { target in
                            HStack(spacing: 12) {
                                SelectionCheckbox(
                                    state: category.selectionState(for: target.id),
                                    isEnabled: !isBusy,
                                    action: { onToggleTarget(target.id) }
                                )
                                Text(target.displayName)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(humanBytes(target.bytes))
                                    .frame(width: 92, alignment: .trailing)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Text(formattedDate(target.modifiedAt))
                                    .frame(width: 140, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.displayName)
                            if let note = group.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "—"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
