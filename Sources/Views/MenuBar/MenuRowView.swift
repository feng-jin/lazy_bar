/// 菜单栏面板中的单行交互项，负责整行命中和 hover 高亮。
import SwiftUI

struct MenuRow: Identifiable {
    let id = UUID()
    let title: String
    let role: ButtonRole?
    let action: () -> Void

    init(title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }
}

struct MenuRowView: View {
    let row: MenuRow

    @State private var isHovered = false

    var body: some View {
        Button(role: row.role, action: row.action) {
            HStack(spacing: 8) {
                Text(row.title)
                    .foregroundStyle(foregroundStyle)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .background(backgroundShape)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var foregroundStyle: AnyShapeStyle {
        if row.role == .destructive {
            return AnyShapeStyle(isHovered ? Color.white : Color.red)
        }

        return AnyShapeStyle(isHovered ? Color.white : Color.primary)
    }

    @ViewBuilder
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isHovered ? Color.accentColor : Color.clear)
    }
}

#Preview {
    VStack(spacing: 4) {
        MenuRowView(row: .init(title: "设置", action: {}))
        MenuRowView(row: .init(title: "退出", role: .destructive, action: {}))
    }
    .padding()
    .frame(width: 188)
}
