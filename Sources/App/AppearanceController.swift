import AppKit

/// 使用者選的外觀（跟隨系統、淺色、深色），套用到整個 App 並記住選擇。
@MainActor
final class AppearanceController: ObservableObject {
    static let shared = AppearanceController()

    enum Mode: String {
        case system, light, dark
    }

    private static let defaultsKey = "OKMMeadAppearance"

    @Published private(set) var mode: Mode

    private init() {
        mode = Mode(rawValue: UserDefaults.standard.string(forKey: Self.defaultsKey) ?? "") ?? .system
    }

    /// App 啟動完成後才有 `NSApp` 可以設定，所以由第一個視窗出現時呼叫。
    func apply() {
        switch mode {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func set(_ newMode: Mode) {
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: Self.defaultsKey)
        apply()
    }

    /// 在目前看到的外觀與另一種之間切換。
    func toggle() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        set(isDark ? .light : .dark)
    }
}
