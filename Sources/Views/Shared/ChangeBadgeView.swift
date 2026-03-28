/// 统一展示涨跌方向的徽标视图，封装图标、颜色和胶囊样式。
import SwiftUI

struct ChangeBadgeView: View {
    let text: String
    let change: QuoteChange

    var body: some View {
        Label(text, systemImage: change.symbolName)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(change.tintColor.opacity(0.14), in: Capsule())
            .foregroundStyle(change.tintColor)
    }
}

#Preview {
    ChangeBadgeView(text: "+1.24%", change: .up)
        .padding()
}
