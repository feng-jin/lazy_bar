/// 提供菜单栏展示字段与颜色策略的设置界面。
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: MenuBarSettingsViewModel

    var body: some View {
        Form {
            Section("展示字段") {
                Toggle(
                    "股票代码",
                    isOn: binding(
                        get: \.showsSymbol,
                        set: viewModel.setShowsSymbol
                    )
                )
                Toggle(
                    "股票简称",
                    isOn: binding(
                        get: \.showsCompanyName,
                        set: viewModel.setShowsCompanyName
                    )
                )
                Toggle(
                    "当前股价",
                    isOn: binding(
                        get: \.showsPrice,
                        set: viewModel.setShowsPrice
                    )
                )
                Toggle(
                    "涨跌幅",
                    isOn: binding(
                        get: \.showsChangePercent,
                        set: viewModel.setShowsChangePercent
                    )
                )
            }

            Section("显示样式") {
                Toggle(
                    "显示颜色",
                    isOn: binding(
                        get: \.usesChangeColor,
                        set: viewModel.setUsesChangeColor
                    )
                )
            }

            Section {
                Text("菜单栏会根据这里的配置即时更新展示内容；如果把所有字段都关闭，会自动回退为显示股票简称。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 360)
    }

    private func binding(
        get keyPath: KeyPath<MenuBarDisplaySettings, Bool>,
        set setter: @escaping (Bool) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { viewModel.settings[keyPath: keyPath] },
            set: setter
        )
    }
}
