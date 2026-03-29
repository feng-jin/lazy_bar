/// 菜单栏展开后的自定义下拉面板。
import SwiftUI

struct BarDropdownView: View {
    let primaryRows: [MenuRow]
    let destructiveRows: [MenuRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(primaryRows) { row in
                MenuRowView(row: row)
            }

            ForEach(destructiveRows) { row in
                MenuRowView(row: row)
            }
        }
        .padding(.horizontal,4)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(width: 185)
        .background(.regularMaterial)
    }
}

#Preview {
    BarDropdownView(
        primaryRows: [
            .init(title: "设置 Settings", action: {})
        ],
        destructiveRows: [
            .init(title: "退出 Quit Lazy Bar", role: .destructive, action: {})
        ]
    )
    .padding()
    .frame(width: 185)
}
