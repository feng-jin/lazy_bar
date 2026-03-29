/// 提供菜单栏展示字段的设置界面。
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MenuBarSettingsViewModel
    let onClose: (() -> Void)?

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

            Section {
                Text("设置页会先保留未保存的草稿；点击保存后菜单栏才会更新。如果把所有字段都关闭，会自动回退为显示股票简称。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()

                    Button("取消") {
                        viewModel.cancel()
                        close()
                    }

                    Button("保存") {
                        viewModel.save()
                        close()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.hasUnsavedChanges)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 360)
        .onAppear {
            viewModel.beginEditing()
        }
    }

    private func binding(
        get keyPath: KeyPath<MenuBarDisplaySettings, Bool>,
        set setter: @escaping (Bool) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { viewModel.draftSettings[keyPath: keyPath] },
            set: setter
        )
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
