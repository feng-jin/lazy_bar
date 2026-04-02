/// 通用卡片容器，用来统一详情区块的背景、圆角和间距风格。
import SwiftUI

struct SectionCardView<Content: View>: View {
    private let title: String?
    private let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05))
        )
    }
}

#Preview {
    SectionCardView(title: "概览") {
        Text("示例内容")
    }
    .padding()
}
