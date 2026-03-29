/// 菜单栏上的紧凑标签，展示公司名称和当日涨跌幅。
import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        if let quote = viewModel.displayQuote {
            HStack(spacing: 6) {
                Text(quote.menuBarNameText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(quote.changePercentText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(quote.change.tintColor)
            }
        } else if viewModel.isLoading {
            Text("加载中...")
                .font(.system(size: 12, weight: .medium, design: .rounded))
        } else {
            Text("行情不可用")
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
    }
}

#Preview {
    MenuBarLabelView(viewModel: PreviewMocks.menuBarViewModel)
        .padding()
}
