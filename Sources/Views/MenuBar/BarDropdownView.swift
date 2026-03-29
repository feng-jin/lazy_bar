/// 菜单栏展开后的自定义下拉面板。
import SwiftUI

struct BarDropdownView: View {
    let primaryRows: [MenuRow]
    let destructiveRows: [MenuRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(primaryRows) { row in
                MenuRowView(row: row)
            }

            if !primaryRows.isEmpty && !destructiveRows.isEmpty {
                Divider()
                    .padding(.vertical, 6)
            }

            ForEach(destructiveRows) { row in
                MenuRowView(row: row)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(width: 160)
        .background(.regularMaterial)
    }
}

#Preview {
    BarDropdownView(
        primaryRows: [
            .init(title: "设置", action: {})
        ],
        destructiveRows: [
            .init(title: "退出", role: .destructive, action: {})
        ]
    )
    .padding()
    .frame(width: 160)
}
