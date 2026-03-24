import AppKit
import SwiftUI
import GarbagemanCore

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            List(
                selection: Binding(
                    get: { viewModel.selectedCategoryID },
                    set: { viewModel.selectCategory($0) }
                )
            ) {
                ForEach(SidebarSection.allCases) { section in
                    let categories = viewModel.categories.filter { $0.section == section }
                    if !categories.isEmpty {
                        Section(section.rawValue) {
                            ForEach(categories) { category in
                                SidebarRow(
                                    category: category,
                                    isBusy: viewModel.isScanning || viewModel.isCleaning,
                                    onToggleSelection: { viewModel.toggleCategorySelection(category) }
                                )
                                .tag(category.id)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct SidebarRow: View {
    @ObservedObject var category: CategoryViewModel
    let isBusy: Bool
    let onToggleSelection: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SelectionCheckbox(
                state: category.checkboxState,
                isEnabled: category.isSelectable && !isBusy,
                action: onToggleSelection
            )

            Image(systemName: category.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(category.sidebarName)
                .lineLimit(1)

            Spacer(minLength: 8)
            trailingStatus
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailingStatus: some View {
        switch category.scanState {
        case .idle:
            Text("—")
                .foregroundStyle(.secondary)
        case .scanning:
            ProgressView()
                .controlSize(.small)
        case .finished:
            if category.isUnavailable {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            } else {
                Text(humanBytes(category.totalBytes))
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.12))
                    )
            }
        }
    }
}
