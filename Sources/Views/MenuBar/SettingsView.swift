/// 提供菜单栏展示字段的设置界面。
import os
import SwiftUI

struct SettingsView: View {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lazy_bar",
        category: "SettingsView"
    )

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MenuBarSettingsViewModel
    let onClose: (() -> Void)?
    @State private var selectedTab: SettingsTab = .watchlist
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchComposerFrame: CGRect = .zero
    @State private var searchResultsFrame: CGRect = .zero

    private let settingsCoordinateSpace = "SettingsViewSpace"

    private enum LayoutMetrics {
        static let watchlistMaxVisibleRows = 7
        static let watchlistRowHeight: CGFloat = 44
        static let watchlistListVerticalPadding: CGFloat = 12
        static let watchlistSectionCornerRadius: CGFloat = 14
        static let searchResultsTopOffset: CGFloat = 58
        static let searchResultsMinHeight: CGFloat = 156
        static let searchResultsMaxHeight: CGFloat = 220
        static let symbolColumnWidth: CGFloat = 108
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

    private struct DisplayModeOption: Identifiable {
        let mode: MenuBarDisplaySettings.DisplayMode

        var id: String { mode.id }
        var title: String { mode.title }
        var description: String { mode.description }
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

            Group {
                switch selectedTab {
                case .watchlist:
                    VStack(alignment: .leading, spacing: 18) {
                        watchlistTabContent
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                case .displayFields:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            displayFieldsTabContent
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
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
        .coordinateSpace(name: settingsCoordinateSpace)
        .simultaneousGesture(
            SpatialTapGesture().onEnded { value in
                handlePanelTap(at: value.location)
            }
        )
        .onChange(of: isSearchFieldFocused) { _, isFocused in
            if isFocused {
                viewModel.revealSearchOverlayIfNeeded()
            } else {
                _ = viewModel.dismissSearchIfNeeded(reason: "focusLost")
            }
        }
        .onExitCommand {
            if viewModel.dismissSearchIfNeeded(reason: "exitCommand") {
                isSearchFieldFocused = false
            }
        }
    }

    private var watchlistTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("输入股票简称、代码或拼音缩写后搜索，再从候选列表里选择要加入监控的股票。")
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

            displayModeSection

            VStack(alignment: .leading, spacing: 10) {
                Text("展示字段")
                    .font(.headline)

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
                            isOn: fieldBinding(for: option.field)
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
    }

    private var displayModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("展示模式")
                .font(.headline)

            ForEach(displayModeOptions) { option in
                displayModeCard(for: option)
            }

            Text("固定模式下，可在左键列表中点选要固定显示的股票；若当前固定项已不在监控列表中，会自动回退到第一只。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func displayModeCard(for option: DisplayModeOption) -> some View {
        let isSelected = viewModel.displayMode() == option.mode

        return Button {
            viewModel.setDisplayMode(option.mode)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(option.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(option.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(cardBackground(for: isSelected))
            .overlay {
                RoundedRectangle(cornerRadius: LayoutMetrics.fieldCardCornerRadius)
                    .strokeBorder(cardBorderColor(for: isSelected), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: LayoutMetrics.fieldCardCornerRadius))
        }
        .buttonStyle(.plain)
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

                Text("\(viewModel.watchlistRows.count) 只")
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

            if viewModel.watchlistRows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前还没有股票")
                        .font(.headline)
                    Text("先在上方搜索并选择股票；保存前你还可以继续修改或删除。")
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
                        ForEach(viewModel.watchlistRows) { row in
                            watchlistRow(for: row)

                            if row.id != viewModel.watchlistRows.last?.id {
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
        VStack(alignment: .leading, spacing: 6) {
            Text("搜索股票")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                "输入简称、代码或拼音缩写，例如：贵州茅台 / 600519 / gzmt",
                text: $viewModel.searchQuery
            )
            .textFieldStyle(.roundedBorder)
            .focused($isSearchFieldFocused)
            .onSubmit {
                viewModel.selectFirstSearchResultIfAvailable()
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        searchComposerFrame = proxy.frame(in: .named(settingsCoordinateSpace))
                    }
                    .onChange(of: proxy.frame(in: .named(settingsCoordinateSpace))) { _, frame in
                        searchComposerFrame = frame
                    }
            }
        )
        .overlay(alignment: .topLeading) {
            if viewModel.showsSearchResults {
                searchResultsList
                    .padding(.top, LayoutMetrics.searchResultsTopOffset)
                    .allowsHitTesting(viewModel.showsSearchResults)
                    .zIndex(1)
            }
        }
        .padding(.horizontal, 16)
        .zIndex(1)
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
                text: watchlistCompanyNameBinding(for: row.id)
            )
            .textFieldStyle(.plain)

            TextField(
                "代码",
                text: watchlistSymbolBinding(for: row.id)
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

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在搜索…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            } else if let message = viewModel.searchStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.searchResults) { result in
                            searchResultRow(for: result)

                            if result.id != viewModel.searchResults.last?.id {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
                .frame(
                    minHeight: LayoutMetrics.searchResultsMinHeight,
                    maxHeight: LayoutMetrics.searchResultsMaxHeight
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        searchResultsFrame = proxy.frame(in: .named(settingsCoordinateSpace))
                    }
                    .onChange(of: proxy.frame(in: .named(settingsCoordinateSpace))) { _, frame in
                        searchResultsFrame = frame
                    }
            }
        )
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.secondary.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    private func searchResultRow(for result: StockSearchResult) -> some View {
        let isAdded = viewModel.isSearchResultAlreadyAdded(result)

        return Button {
            viewModel.selectSearchResult(result)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.companyName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(result.marketSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(result.symbol)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                if isAdded {
                    Text("已添加")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func dismissSearchOverlay(reason: String) {
        if viewModel.dismissSearchIfNeeded(reason: reason) {
            isSearchFieldFocused = false
        }
    }

    private func handlePanelTap(at location: CGPoint) {
        guard viewModel.showsSearchResults else { return }

        let tappedComposer = searchComposerFrame.contains(location)
        let tappedResults = searchResultsFrame.contains(location)
        Self.logger.debug(
            """
            handlePanelTap location=(\(location.x, privacy: .public),\(location.y, privacy: .public)) \
            composerHit=\(tappedComposer, privacy: .public) \
            resultsHit=\(tappedResults, privacy: .public)
            """
        )

        guard !tappedComposer && !tappedResults else {
            return
        }

        dismissSearchOverlay(reason: "panelTapOutsideSearch")
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

    private var displayModeOptions: [DisplayModeOption] {
        MenuBarDisplaySettings.DisplayMode.allCases.map { DisplayModeOption(mode: $0) }
    }

    private func fieldBinding(for field: MenuBarDisplaySettings.Field) -> Binding<Bool> {
        Binding(
            get: { viewModel.showsField(field) },
            set: { viewModel.setField(field, isVisible: $0) }
        )
    }

    private func watchlistCompanyNameBinding(for id: MenuBarSettingsViewModel.WatchlistDraftRow.ID) -> Binding<String> {
        Binding(
            get: { viewModel.watchlistEntryCompanyName(id: id) },
            set: { viewModel.updateWatchlistEntryCompanyName(id: id, input: $0) }
        )
    }

    private func watchlistSymbolBinding(for id: MenuBarSettingsViewModel.WatchlistDraftRow.ID) -> Binding<String> {
        Binding(
            get: { viewModel.watchlistEntrySymbol(id: id) },
            set: { viewModel.updateWatchlistEntrySymbol(id: id, input: $0) }
        )
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
