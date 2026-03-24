import SwiftUI
import GarbagemanCore

struct SummaryBannerView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 10) {
            if viewModel.isCleaning, let progress = viewModel.cleanProgress {
                HStack {
                    Text("Cleaning…")
                    Spacer()
                    Text("\(progress.completedUnitCount) / \(progress.totalUnitCount) items")
                        .monospacedDigit()
                }

                ProgressView(
                    value: Double(progress.completedUnitCount),
                    total: Double(max(progress.totalUnitCount, 1))
                )

                HStack {
                    Text(progress.currentDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                HStack {
                    Text(summaryText)
                    Spacer()
                    Button("Delete Selected") {
                        viewModel.presentConfirmation()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canClean)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var summaryText: String {
        if viewModel.selectedBytes > 0 {
            return "\(viewModel.selectedCategoryCount) categories selected · \(humanBytes(viewModel.selectedBytes)) reclaimable"
        }

        if let lastCleanupBytes = viewModel.lastCleanupBytes {
            return "✓ \(humanBytes(lastCleanupBytes)) cleaned"
        }

        return "No cleanup category selected"
    }
}
