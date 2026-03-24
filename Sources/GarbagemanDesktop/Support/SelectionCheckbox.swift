import SwiftUI

enum CheckboxState {
    case off
    case on
    case mixed
}

struct SelectionCheckbox: View {
    let state: CheckboxState
    let isEnabled: Bool
    let action: () -> Void

    private var symbolName: String {
        switch state {
        case .off:
            return "square"
        case .on:
            return "checkmark.square.fill"
        case .mixed:
            return "minus.square.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary.opacity(0.7))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(isEnabled ? "Toggle selection" : "This category cannot be cleaned right now")
    }
}
