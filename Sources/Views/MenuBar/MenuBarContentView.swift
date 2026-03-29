/// 点击菜单栏项后展示的原生菜单内容。
import AppKit
import SwiftUI

struct MenuBarContentView: View {
    var body: some View {
        Group {
            SettingsLink {
                Label("设置 Settings", systemImage: "gearshape")
            }

            Divider()

            Button(action: quitApp) {
                Label("退出 Quit Lazy Bar", systemImage: "power")
            }
        }
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }
}

struct MenuBarContentView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarContentView()
    }
}
