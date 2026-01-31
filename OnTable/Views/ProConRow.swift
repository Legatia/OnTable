import SwiftUI

struct ProConRow: View {
    let proCon: ProCon
    let onWeightChange: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Weight indicator
            Circle()
                .fill(proCon.type == .pro ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                .frame(width: weightSize, height: weightSize)
                .overlay(
                    Text("\(proCon.weight.rawValue)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(proCon.type == .pro ? .green : .red)
                )

            // Text
            Text(proCon.text)
                .font(textFont)
                .fontWeight(textWeight)
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()

            // Added by (if not "me")
            if proCon.addedBy != "me" {
                Text(proCon.addedBy)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(backgroundColor)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onWeightChange()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var weightSize: CGFloat {
        switch proCon.weight {
        case .normal: return 20
        case .bold: return 24
        case .huge: return 28
        }
    }

    private var textFont: Font {
        switch proCon.weight {
        case .normal: return .subheadline
        case .bold: return .body
        case .huge: return .headline
        }
    }

    private var textWeight: Font.Weight {
        switch proCon.weight {
        case .normal: return .regular
        case .bold: return .medium
        case .huge: return .bold
        }
    }

    private var backgroundColor: Color {
        let baseColor = proCon.type == .pro ? Color.green : Color.red
        switch proCon.weight {
        case .normal: return baseColor.opacity(0.05)
        case .bold: return baseColor.opacity(0.1)
        case .huge: return baseColor.opacity(0.15)
        }
    }
}

// MARK: - Preview

struct ProConRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            ProConRow(
                proCon: ProCon(text: "Good price", weight: .normal, type: .pro),
                onWeightChange: {},
                onDelete: {}
            )
            ProConRow(
                proCon: ProCon(text: "Great reviews", weight: .bold, type: .pro),
                onWeightChange: {},
                onDelete: {}
            )
            ProConRow(
                proCon: ProCon(text: "Perfect location", weight: .huge, type: .pro),
                onWeightChange: {},
                onDelete: {}
            )
            ProConRow(
                proCon: ProCon(text: "Expensive", weight: .normal, type: .con),
                onWeightChange: {},
                onDelete: {}
            )
            ProConRow(
                proCon: ProCon(text: "Far from work", weight: .bold, addedBy: "Alex", type: .con),
                onWeightChange: {},
                onDelete: {}
            )
        }
        .padding()
    }
}
