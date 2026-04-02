/// 提供菜单栏展示字段的设置界面。
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MenuBarSettingsViewModel
    let onClose: (() -> Void)?
    @State private var selectedTab: SettingsTab = .watchlist

    private enum LayoutMetrics {
        static let watchlistMaxVisibleRows = 7
        static let watchlistRowHeight: CGFloat = 44
        static let watchlistListVerticalPadding: CGFloat = 12
        static let watchlistSectionCornerRadius: CGFloat = 14
        static let symbolColumnWidth: CGFloat = 108
        static let composerSymbolWidth: CGFloat = 132
        static let actionColumnWidth: CGFloat = 32
        static let fieldCardCornerRadius: CGFloat = 12
    }

    private enum SettingsTab: String, CaseIterable, Identifiable {
        case watchlist
        case displayFields

        var id: String { rawValue }

        var title: String {
            switch self {
            case .watchlist:
                return "监控股票"
            case .displayFields:
                return "展示字段"
            }
        }
    }

    private struct DisplayFieldOption: Identifiable {
        let id: String
        let title: String
        let description: String
        let isOn: () -> Bool
        let setIsOn: (Bool) -> Void
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .watchlist:
                        watchlistTabContent
                    case .displayFields:
                        displayFieldsTabContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            Divider()
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 10) {
                if let validationMessage = viewModel.validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

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
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .frame(width: 500)
        .onAppear {
            viewModel.beginEditing()
        }
    }

    private var watchlistTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("手动维护菜单栏要监控的股票列表。简称用于展示，代码只保留 6 位数字。")
                .font(.callout)
                .foregroundStyle(.secondary)

            watchlistEditorCard
        }
    }

    private var displayFieldsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
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
    }

    private var watchlistEditorCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("监控列表")
                        .font(.headline)
                    Text("保存后才会真正应用到菜单栏。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text("\(viewModel.draftSettings.watchlist.count) 只")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            watchlistComposerRow

            Divider()
                .padding(.horizontal, 16)
                .padding(.top, 14)

            if viewModel.draftSettings.watchlist.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前还没有股票")
                        .font(.headline)
                    Text("填写简称和代码后点“添加”，保存前你还可以继续修改或删除。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: watchlistListHeight, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            } else {
                watchlistTableHeader

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.draftSettings.watchlist) { entry in
                            watchlistRow(for: entry)

                            if entry.id != viewModel.draftSettings.watchlist.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: watchlistListHeight)
            }
        }
        .background(watchlistSectionBackground)
        .overlay {
            RoundedRectangle(cornerRadius: LayoutMetrics.watchlistSectionCornerRadius)
                .strokeBorder(.secondary.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: LayoutMetrics.watchlistSectionCornerRadius))
    }

    private var watchlistComposerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("股票简称")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(
                    "例如：贵州茅台",
                    text: Binding(
                        get: { viewModel.watchlistCompanyNameInput },
                        set: viewModel.updateWatchlistCompanyNameInput
                    )
                )
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("股票代码")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(
                    "600519",
                    text: Binding(
                        get: { viewModel.watchlistSymbolInput },
                        set: viewModel.updateWatchlistSymbolInput
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(width: LayoutMetrics.composerSymbolWidth)
            }

            Button("添加") {
                viewModel.addWatchlistEntry()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canAddWatchlistEntry)
            .padding(.top, 22)
        }
        .padding(.horizontal, 16)
    }

    private var watchlistTableHeader: some View {
        HStack(spacing: 12) {
            Text("简称")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("代码")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: LayoutMetrics.symbolColumnWidth, alignment: .leading)

            Color.clear
                .frame(width: LayoutMetrics.actionColumnWidth, height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.horizontal, 12)
        }
    }

    private func watchlistRow(for entry: MenuBarSettingsViewModel.EditableWatchlistEntry) -> some View {
        HStack(spacing: 12) {
            TextField(
                "股票简称",
                text: Binding(
                    get: { currentEntry(for: entry.id)?.companyName ?? "" },
                    set: { viewModel.updateWatchlistEntryCompanyName(id: entry.id, input: $0) }
                )
            )
            .textFieldStyle(.plain)

            TextField(
                "代码",
                text: Binding(
                    get: { currentEntry(for: entry.id)?.symbol ?? "" },
                    set: { viewModel.updateWatchlistEntrySymbol(id: entry.id, input: $0) }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .frame(width: LayoutMetrics.symbolColumnWidth)

            Button {
                viewModel.removeWatchlistEntry(id: entry.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: LayoutMetrics.actionColumnWidth, height: LayoutMetrics.actionColumnWidth)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.secondary.opacity(0.08), lineWidth: 1)
            }
            .help("删除这只股票")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: LayoutMetrics.watchlistRowHeight)
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

    private func currentEntry(
        for id: MenuBarSettingsViewModel.EditableWatchlistEntry.ID
    ) -> MenuBarSettingsViewModel.EditableWatchlistEntry? {
        viewModel.draftSettings.watchlist.first(where: { $0.id == id })
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var watchlistListHeight: CGFloat {
        CGFloat(LayoutMetrics.watchlistMaxVisibleRows) * LayoutMetrics.watchlistRowHeight + LayoutMetrics.watchlistListVerticalPadding
    }

    private var watchlistSectionBackground: some ShapeStyle {
        AnyShapeStyle(.quaternary.opacity(0.14))
    }

    private var displayFieldOptions: [DisplayFieldOption] {
        [
            DisplayFieldOption(
                id: "companyName",
                title: "股票简称",
                description: "优先显示你自定义维护的股票名称，适合快速扫一眼识别标的。",
                isOn: { viewModel.draftSettings.showsCompanyName },
                setIsOn: viewModel.setShowsCompanyName
            ),
            DisplayFieldOption(
                id: "symbol",
                title: "股票代码",
                description: "展示 6 位代码，适合区分同名或相近简称的股票。",
                isOn: { viewModel.draftSettings.showsSymbol },
                setIsOn: viewModel.setShowsSymbol
            ),
            DisplayFieldOption(
                id: "price",
                title: "当前股价",
                description: "显示最新价格，是菜单栏和主面板里的核心数值字段。",
                isOn: { viewModel.draftSettings.showsPrice },
                setIsOn: viewModel.setShowsPrice
            ),
            DisplayFieldOption(
                id: "changePercent",
                title: "涨跌幅",
                description: "显示相对昨收的百分比变化，便于快速判断强弱。",
                isOn: { viewModel.draftSettings.showsChangePercent },
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
