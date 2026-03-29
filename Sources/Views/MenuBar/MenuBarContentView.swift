/// 点击菜单栏项后展示的操作菜单。
import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        BarDropdownView(
            primaryRows: [
                .init(title: "设置 Settings", systemImage: "gearshape", action: openSettingsWindow)
            ],
            destructiveRows: [
                .init(title: "退出 Quit Lazy Bar", systemImage: "power", role: .destructive, action: quitApp)
            ]
        )
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }

    private func openSettingsWindow() {
        dismiss()

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
    }
}

struct MenuBarContentView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarContentView()
            .padding()
    }
}
