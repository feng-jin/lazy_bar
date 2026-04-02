/// 提供菜单栏展示字段的设置界面。
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MenuBarSettingsViewModel
    let onClose: (() -> Void)?

    private enum LayoutMetrics {
        static let watchlistMaxVisibleRows = 7
        static let watchlistRowHeight: CGFloat = 36
        static let watchlistListVerticalPadding: CGFloat = 8
        static let symbolColumnWidth: CGFloat = 96
        static let actionColumnWidth: CGFloat = 28
    }

    var body: some View {
        Form {
            Section("监控股票") {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    TextField(
                        "股票简称",
                        text: Binding(
                            get: { viewModel.watchlistCompanyNameInput },
                            set: viewModel.updateWatchlistCompanyNameInput
                        )
                    )
                    .textFieldStyle(.roundedBorder)

                    TextField(
                        "代码",
                        text: Binding(
                            get: { viewModel.watchlistSymbolInput },
                            set: viewModel.updateWatchlistSymbolInput
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: LayoutMetrics.symbolColumnWidth)

                    Spacer(minLength: 0)

                    Button("+") {
                        viewModel.addWatchlistEntry()
                    }
                    .frame(width: LayoutMetrics.actionColumnWidth)
                    .disabled(!viewModel.canAddWatchlistEntry)
                }

                if viewModel.draftWatchlist.isEmpty {
                    Text("当前未配置监控股票，保存后菜单栏和主面板会显示为空。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.draftWatchlist) { entry in
                                HStack(spacing: 12) {
                                    TextField(
                                        "股票简称",
                                        text: Binding(
                                            get: { currentCompanyName(for: entry.id) },
                                            set: { viewModel.updateWatchlistEntryCompanyName(id: entry.id, input: $0) }
                                        )
                                    )
                                    .textFieldStyle(.roundedBorder)

                                    TextField(
                                        "代码",
                                        text: Binding(
                                            get: { currentSymbol(for: entry.id) },
                                            set: { viewModel.updateWatchlistEntrySymbol(id: entry.id, input: $0) }
                                        )
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: LayoutMetrics.symbolColumnWidth)

                                    Button("-") {
                                        viewModel.removeWatchlistEntry(id: entry.id)
                                    }
                                    .frame(width: LayoutMetrics.actionColumnWidth)
                                    .buttonStyle(.borderless)
                                }
                                .frame(minHeight: LayoutMetrics.watchlistRowHeight)

                                if entry.id != viewModel.draftWatchlist.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: watchlistListHeight)
                }

                HStack {
                    Spacer()

                    Button("恢复 Base 列表") {
                        viewModel.resetWatchlistToBase()
                    }
                    .disabled(!viewModel.canResetWatchlistToBase)
                }
            }

            Section("展示字段") {
                Toggle(
                    "股票简称",
                    isOn: binding(
                        get: { viewModel.draftShowsCompanyName },
                        set: viewModel.setShowsCompanyName
                    )
                )
                Toggle(
                    "股票代码",
                    isOn: binding(
                        get: { viewModel.draftShowsSymbol },
                        set: viewModel.setShowsSymbol
                    )
                )
                Toggle(
                    "当前股价",
                    isOn: binding(
                        get: { viewModel.draftShowsPrice },
                        set: viewModel.setShowsPrice
                    )
                )
                Toggle(
                    "涨跌幅",
                    isOn: binding(
                        get: { viewModel.draftShowsChangePercent },
                        set: viewModel.setShowsChangePercent
                    )
                )
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    if let validationMessage = viewModel.validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section {
                HStack {
                    Spacer()

                    Button("保存") {
                        viewModel.save()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canSave)

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
        get getter: @escaping () -> Bool,
        set setter: @escaping (Bool) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: getter,
            set: setter
        )
    }

    private func currentCompanyName(for id: MenuBarSettingsViewModel.EditableWatchlistEntry.ID) -> String {
        viewModel.draftWatchlist.first(where: { $0.id == id })?.companyName ?? ""
    }

    private func currentSymbol(for id: MenuBarSettingsViewModel.EditableWatchlistEntry.ID) -> String {
        viewModel.draftWatchlist.first(where: { $0.id == id })?.symbol ?? ""
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var watchlistListHeight: CGFloat {
        let visibleRowCount = min(
            viewModel.draftWatchlist.count,
            LayoutMetrics.watchlistMaxVisibleRows
        )
        return CGFloat(visibleRowCount) * LayoutMetrics.watchlistRowHeight + LayoutMetrics.watchlistListVerticalPadding
    }
}
