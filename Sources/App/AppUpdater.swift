/// 封装 Sparkle 更新能力，并在配置缺失时给出可操作的提示。
import AppKit
import os
import Sparkle

@MainActor
final class AppUpdater {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lazy_bar",
        category: "AppUpdater"
    )

    private enum ConfigurationKeys {
        static let feedURL = "SUFeedURL"
        static let publicEDKey = "SUPublicEDKey"
    }

    private let updaterController: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        guard Self.hasRequiredConfiguration(in: bundle) else {
            updaterController = nil
            Self.logger.error("Sparkle updater disabled because SUFeedURL or SUPublicEDKey is missing")
            return
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        Self.logger.debug("Sparkle updater initialized")
    }

    func checkForUpdates() {
        guard let updaterController else {
            Self.logger.error("checkForUpdates failed because Sparkle configuration is incomplete")
            showMissingConfigurationAlert()
            return
        }

        Self.logger.debug("checkForUpdates")
        updaterController.checkForUpdates(nil)
    }

    private static func hasRequiredConfiguration(in bundle: Bundle) -> Bool {
        guard
            let feedURL = bundle.object(forInfoDictionaryKey: ConfigurationKeys.feedURL) as? String,
            let publicEDKey = bundle.object(forInfoDictionaryKey: ConfigurationKeys.publicEDKey) as? String
        else {
            return false
        }

        return !feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !publicEDKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func showMissingConfigurationAlert() {
        NSApp.activate()

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "升级功能还没配置完成"
        alert.informativeText =
            "请先在 build settings 或 Info.plist 中填写 Sparkle 的 SUFeedURL 和 SUPublicEDKey，再重新构建应用。"
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }
}
