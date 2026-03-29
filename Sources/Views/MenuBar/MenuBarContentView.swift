/// 点击菜单栏项后展示的原生菜单内容。
import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            Button(action: openSettingsWindow) {
                Label("设置 Settings", systemImage: "gearshape")
            }

            Button(action: quitApp) {
                Label("退出 Quit Lazy Bar", systemImage: "power")
            }
        }
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }

    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }
}

struct MenuBarContentView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarContentView()
    }
}
