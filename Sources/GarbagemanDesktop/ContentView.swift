import SwiftUI
import GarbagemanCore

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let category = viewModel.permissionBannerCategory {
                PermissionBannerView(
                    categoryName: category.displayName,
                    message: category.permissionMessage,
                    onOpenSettings: viewModel.openSystemSettings,
                    onIgnore: viewModel.dismissPermissionBanner
                )
                .padding([.horizontal, .top], 16)
                .padding(.bottom, 8)
            }

            NavigationSplitView {
                SidebarView(viewModel: viewModel)
            } detail: {
                if let category = viewModel.selectedCategory {
                    CategoryDetailView(
                        category: category,
                        isBusy: viewModel.isScanning || viewModel.isCleaning,
                        onScan: viewModel.scan,
                        onToggleAll: { viewModel.toggleAllTargets(in: category) },
                        onToggleTarget: { targetID in
                            viewModel.toggleTarget(targetID, in: category)
                        }
                    )
                } else {
                    EmptyStateView(
                        icon: "sparkles",
                        title: "Nothing scanned yet",
                        message: "Run a scan to estimate how much space you can reclaim.",
                        buttonTitle: "Scan",
                        action: viewModel.scan
                    )
                }
            }

            Divider()
            SummaryBannerView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(viewModel.isScanning ? "Scanning…" : "Scan") {
                    viewModel.scan()
                }
                .disabled(viewModel.isScanning || viewModel.isCleaning)
            }
        }
        .sheet(isPresented: $viewModel.showingConfirmationSheet) {
            CleanupConfirmationSheet(
                totalBytes: viewModel.selectedBytes,
                items: viewModel.cleanupSummaryItems,
                onCancel: { viewModel.showingConfirmationSheet = false },
                onConfirm: viewModel.performCleanup
            )
        }
        .alert(
            "Cleanup issues",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

private struct CleanupConfirmationSheet: View {
    let totalBytes: Int64
    let items: [CleanupSummaryItem]
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("\(humanBytes(totalBytes)) will be removed")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    HStack {
                        Text("• \(item.displayName)")
                        Spacer()
                        Text(humanBytes(item.bytes))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            Text("This action cannot be undone.")
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Delete", role: .destructive, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
