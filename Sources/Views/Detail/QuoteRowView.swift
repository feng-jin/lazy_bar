import SwiftUI

struct QuoteRowView: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
    }
}

#Preview {
    QuoteRowView(title: "更新时间", value: "14:35")
        .padding()
}
