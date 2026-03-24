import Foundation
import GarbagemanCore

enum SidebarSection: String, CaseIterable, Identifiable {
    case system = "SYSTEM"
    case xcode = "XCODE"
    case packages = "PACKAGES"
    case android = "ANDROID"
    case other = "OTHER"

    var id: String { rawValue }
}

struct CategoryPresentation {
    let sidebarName: String
    let icon: String
    let section: SidebarSection
}

extension CategoryID {
    var presentation: CategoryPresentation {
        switch self {
        case .caches:
            return CategoryPresentation(sidebarName: "Caches", icon: "externaldrive.badge.timemachine", section: .system)
        case .logs:
            return CategoryPresentation(sidebarName: "Logs", icon: "doc.text.magnifyingglass", section: .system)
        case .trash:
            return CategoryPresentation(sidebarName: "Trash", icon: "trash", section: .system)
        case .xcode:
            return CategoryPresentation(sidebarName: "DerivedData", icon: "hammer", section: .xcode)
        case .simulators:
            return CategoryPresentation(sidebarName: "Simulators", icon: "iphone", section: .xcode)
        case .brew:
            return CategoryPresentation(sidebarName: "Homebrew", icon: "cup.and.saucer", section: .packages)
        case .npm:
            return CategoryPresentation(sidebarName: "npm", icon: "shippingbox", section: .packages)
        case .pip:
            return CategoryPresentation(sidebarName: "pip", icon: "terminal", section: .packages)
        case .yarn:
            return CategoryPresentation(sidebarName: "Yarn", icon: "shippingbox.circle", section: .packages)
        case .gradle:
            return CategoryPresentation(sidebarName: "Gradle", icon: "gearshape.2", section: .packages)
        case .pods:
            return CategoryPresentation(sidebarName: "CocoaPods", icon: "shippingbox.circle.fill", section: .packages)
        case .android:
            return CategoryPresentation(sidebarName: "Emulator Snapshots", icon: "pc", section: .android)
        case .docker:
            return CategoryPresentation(sidebarName: "Docker", icon: "shippingbox.and.arrow.backward", section: .other)
        case .downloads:
            return CategoryPresentation(sidebarName: "Downloads", icon: "arrow.down.circle", section: .other)
        case .iosBackups:
            return CategoryPresentation(sidebarName: "iOS Backups", icon: "iphone.gen3.radiowaves.left.and.right", section: .other)
        }
    }
}
