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
        static let fieldCardCornerRadius: CGFloat = 12
    }

    private struct DisplayFieldOption: Identifiable {
        let id: String
        let title: String
        let description: String
        let isOn: () -> Bool
        let setIsOn: (Bool) -> Void
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
                Text("控制 bar 和主面板股票列表里要显示的字段组合。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12, alignment: .top),
                        GridItem(.flexible(), spacing: 12, alignment: .top)
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(displayFieldOptions) { option in
                        Toggle(
                            isOn: binding(
                                get: option.isOn,
                                set: option.setIsOn
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(option.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text(option.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(cardBackground(for: option.isOn()))
                            .overlay {
                                RoundedRectangle(cornerRadius: LayoutMetrics.fieldCardCornerRadius)
                                    .strokeBorder(cardBorderColor(for: option.isOn()), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: LayoutMetrics.fieldCardCornerRadius))
                        }
                        .toggleStyle(.checkbox)
                    }
                }
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
        .frame(width: 500)
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

    private var displayFieldOptions: [DisplayFieldOption] {
        [
            DisplayFieldOption(
                id: "companyName",
                title: "股票简称",
                description: "优先显示你自定义维护的股票名称，适合快速扫一眼识别标的。",
                isOn: { viewModel.draftShowsCompanyName },
                setIsOn: viewModel.setShowsCompanyName
            ),
            DisplayFieldOption(
                id: "symbol",
                title: "股票代码",
                description: "展示 6 位代码，适合区分同名或相近简称的股票。",
                isOn: { viewModel.draftShowsSymbol },
                setIsOn: viewModel.setShowsSymbol
            ),
            DisplayFieldOption(
                id: "price",
                title: "当前股价",
                description: "显示最新价格，是菜单栏和主面板里的核心数值字段。",
                isOn: { viewModel.draftShowsPrice },
                setIsOn: viewModel.setShowsPrice
            ),
            DisplayFieldOption(
                id: "changePercent",
                title: "涨跌幅",
                description: "显示相对昨收的百分比变化，便于快速判断强弱。",
                isOn: { viewModel.draftShowsChangePercent },
                setIsOn: viewModel.setShowsChangePercent
            )
        ]
    }

    private func cardBackground(for isSelected: Bool) -> some ShapeStyle {
        isSelected
            ? AnyShapeStyle(.tint.opacity(0.12))
            : AnyShapeStyle(.quaternary.opacity(0.18))
    }

    private func cardBorderColor(for isSelected: Bool) -> Color {
        isSelected ? .accentColor.opacity(0.45) : .secondary.opacity(0.14)
    }
}
