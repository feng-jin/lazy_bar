/// 点击菜单栏项后展示的操作菜单。
import AppKit
import SwiftUI

@available(macOS 15.0, *)
struct MenuBarContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsLink {
                Text("设置")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Button(role: .destructive, action: quitApp) {
                Text("退出")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 180)
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }
}

@available(macOS 15.0, *)
struct MenuBarContentView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarContentView()
            .padding()
    }
}
