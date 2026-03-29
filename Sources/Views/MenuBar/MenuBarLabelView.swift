/// 菜单栏上的紧凑标签，展示公司名称、最新价和当日涨跌幅。
import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    let settings: MenuBarDisplaySettings

    var body: some View {
        if let quote = viewModel.displayQuote {
            menuBarText(for: quote)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
        } else if viewModel.isLoading {
            Text("加载中...")
                .font(.system(size: 12, weight: .medium, design: .rounded))
        } else {
            Text("行情不可用")
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
    }

    private func menuBarText(for quote: DisplayQuote) -> Text {
        let segments = quote.menuBarSegments(settings: settings)

        guard let firstSegment = segments.first else {
            return Text(quote.menuBarNameText)
        }

        return segments.dropFirst().reduce(styledText(for: firstSegment, quote: quote)) { partial, segment in
            partial + Text(" ") + styledText(for: segment, quote: quote)
        }
    }

    private func styledText(for segment: DisplayQuote.MenuBarSegment, quote: DisplayQuote) -> Text {
        let text = Text(segment.text)

        guard settings.usesChangeColor, segment.emphasizesChange else {
            return text.foregroundColor(.primary)
        }

        return text.foregroundColor(quote.change.tintColor)
    }
}

#Preview {
    MenuBarLabelView(
        viewModel: PreviewMocks.menuBarViewModel,
        settings: .default
    )
        .padding()
}
