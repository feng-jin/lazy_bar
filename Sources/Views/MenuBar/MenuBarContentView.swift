/// 点击菜单栏项后展示的操作菜单。
import AppKit
import SwiftUI

struct MenuBarContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            Button("设置", action: openSettings)
            Divider()
            Button("退出", role: .destructive, action: quitApp)
        }
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }
}

#Preview {
    MenuBarContentView()
        .padding()
}
