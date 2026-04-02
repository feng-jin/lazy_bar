/// 提供菜单栏展示字段的设置界面。
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MenuBarSettingsViewModel
    let onClose: (() -> Void)?

    private enum LayoutMetrics {
        static let watchlistMaxVisibleRows = 5
        static let watchlistRowHeight: CGFloat = 30
        static let watchlistListVerticalPadding: CGFloat = 8
    }

    var body: some View {
        Form {
            Section("监控股票") {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    TextField(
                        "股票简称",
                        text: Binding(
                            get: { viewModel.watchlistNameInput },
                            set: viewModel.updateWatchlistNameInput
                        )
                    )
                    .textFieldStyle(.roundedBorder)

                    TextField(
                        "输入 6 位股票代码",
                        text: Binding(
                            get: { viewModel.watchlistSymbolInput },
                            set: viewModel.updateWatchlistSymbolInput
                        )
                    )
                    .textFieldStyle(.roundedBorder)

                    Button("添加") {
                        viewModel.addWatchlistEntry()
                    }
                    .disabled(
                        normalizedWatchlistSymbolInput.count != 6 ||
                        normalizedWatchlistNameInput.isEmpty
                    )
                }

                if viewModel.draftSettings.watchlist.isEmpty {
                    Text("当前未配置监控股票，保存后菜单栏和主面板会显示为空。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.draftSettings.watchlist, id: \.symbol) { entry in
                                HStack(spacing: 12) {
                                    Text(entry.companyName)
                                        .lineLimit(1)

                                    Text(entry.symbol)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Button("删除") {
                                        viewModel.removeWatchlistEntry(symbol: entry.symbol)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .frame(minHeight: LayoutMetrics.watchlistRowHeight)

                                if entry.symbol != viewModel.draftSettings.watchlist.last?.symbol {
                                    Divider()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: watchlistListHeight)
                }
            }

            Section("展示字段") {
                Toggle(
                    "股票简称",
                    isOn: binding(
                        get: \.showsCompanyName,
                        set: viewModel.setShowsCompanyName
                    )
                )
                Toggle(
                    "股票代码",
                    isOn: binding(
                        get: \.showsSymbol,
                        set: viewModel.setShowsSymbol
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
                Text("设置页会先保留未保存的草稿；点击保存后菜单栏和监控列表才会更新。监控列表通过股票简称和 6 位股票代码维护，重复代码会自动忽略。如果把所有展示字段都关闭，会自动回退为显示股票简称。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()

                    Button("保存") {
                        viewModel.save()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.hasUnsavedChanges)

                    Button("取消") {
                        viewModel.cancel()
                        close()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
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

    private var normalizedWatchlistSymbolInput: String {
        viewModel.watchlistSymbolInput.filter(\.isNumber)
    }

    private var normalizedWatchlistNameInput: String {
        viewModel.watchlistNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var watchlistListHeight: CGFloat {
        let visibleRowCount = min(
            viewModel.draftSettings.watchlist.count,
            LayoutMetrics.watchlistMaxVisibleRows
        )
        return CGFloat(visibleRowCount) * LayoutMetrics.watchlistRowHeight + LayoutMetrics.watchlistListVerticalPadding
    }
}
