import SwiftUI

struct PermissionBannerView: View {
    let categoryName: String
    let message: String
    let onOpenSettings: () -> Void
    let onIgnore: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(categoryName) needs Full Disk Access")
                    .font(.headline)
                Text(message)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open System Settings", action: onOpenSettings)
            Button("Ignore", action: onIgnore)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.yellow.opacity(0.15))
        )
    }
}
