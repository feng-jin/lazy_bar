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
        let field: MenuBarDisplaySettings.Field

        var id: String { field.id }
        var title: String { field.title }
        var description: String { field.description }
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
                        isOn: binding(from: viewModel.binding(for: option.field))
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
                        .background(cardBackground(for: viewModel.draft.settings.showsField(option.field)))
                        .overlay {
                            RoundedRectangle(cornerRadius: LayoutMetrics.fieldCardCornerRadius)
                                .strokeBorder(
                                    cardBorderColor(for: viewModel.draft.settings.showsField(option.field)),
                                    lineWidth: 1
                                )
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

                Text("\(viewModel.draft.watchlistRows.count) 只")
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

            if viewModel.draft.watchlistRows.isEmpty {
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
                        ForEach(viewModel.draft.watchlistRows) { row in
                            watchlistRow(for: row)

                            if row.id != viewModel.draft.watchlistRows.last?.id {
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
                    text: $viewModel.newEntry.companyName
                )
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("股票代码")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(
                    "600519",
                    text: binding(from: viewModel.bindingForNewEntrySymbol())
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(width: LayoutMetrics.composerSymbolWidth)
            }

            Button("添加") {
                viewModel.appendNewEntry()
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

    private func watchlistRow(for row: MenuBarSettingsViewModel.WatchlistDraftRow) -> some View {
        HStack(spacing: 12) {
            TextField(
                "股票简称",
                text: binding(from: viewModel.bindingForWatchlistEntryCompanyName(id: row.id))
            )
            .textFieldStyle(.plain)

            TextField(
                "代码",
                text: binding(from: viewModel.bindingForWatchlistEntrySymbol(id: row.id))
            )
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .frame(width: LayoutMetrics.symbolColumnWidth)

            Button {
                viewModel.removeWatchlistEntry(id: row.id)
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

    private func binding<Value>(from source: BindingValue<Value>) -> Binding<Value> {
        Binding(
            get: source.get,
            set: source.set
        )
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
        MenuBarDisplaySettings.Field.allCases.map { DisplayFieldOption(field: $0) }
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
