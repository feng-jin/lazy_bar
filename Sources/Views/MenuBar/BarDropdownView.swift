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

            if !primaryRows.isEmpty && !destructiveRows.isEmpty {
                Divider()
                    .padding(.vertical, 2)
            }

            ForEach(destructiveRows) { row in
                MenuRowView(row: row)
            }
        }
        .padding(6)
        .frame(width: 188)
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
}
