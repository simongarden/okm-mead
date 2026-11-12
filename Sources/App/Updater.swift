import AppKit
import Sparkle

/// Sparkle 自動更新。更新來源、EdDSA 公鑰與檢查間隔寫在 Info.plist（見 `project.yml`）；
/// `scripts/release.sh` 會簽署 dmg，並把 appcast.xml 附在每個 GitHub Release。
@MainActor
final class Updater {
    static let shared = Updater()
    private var controller: SPUStandardUpdaterController?

    /// 開發建置與測試不啟動：它們不是正式簽署的版本，不應該被更新取代。
    func start() {
        #if !DEBUG
        guard controller == nil else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        #endif
    }

    var isAvailable: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
