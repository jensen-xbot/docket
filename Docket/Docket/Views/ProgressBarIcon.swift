import SwiftUI

/// Three vertical bars that fill progressively (0–33%, 34–66%, 67–100%).
/// At 100%, shows a green checkmark instead.
struct ProgressBarIcon: View {
    let progress: Double // 0.0 - 100.0
    var isActive: Bool = true
    var size: CGFloat = 20
    
    var body: some View {
        Group {
            if progress >= 100 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size))
                    .foregroundStyle(.green)
                    .contentTransition(.symbolEffect(.replace))
            } else {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        BarFillView(progress: progress, barIndex: index)
                    }
                }
                .frame(height: size)
            }
        }
    }
}

private struct BarFillView: View {
    let progress: Double
    let barIndex: Int
    
    private var fillRatio: Double {
        let threshold = Double(barIndex) * 33.34
        guard progress > threshold else { return 0 }
        let segmentProgress = min(1, (progress - threshold) / 33.34)
        return segmentProgress
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.25))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(fillColor)
                    .frame(height: geometry.size.height * fillRatio)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(width: 5)
    }
    
    private var fillColor: Color {
        switch progress {
        case 0..<25: return .gray.opacity(0.6)
        case 25..<75: return .blue.opacity(0.8)
        case 75..<100: return .blue
        default: return .green
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        ProgressBarIcon(progress: 0)
        ProgressBarIcon(progress: 20)
        ProgressBarIcon(progress: 50)
        ProgressBarIcon(progress: 80)
        ProgressBarIcon(progress: 100)
    }
    .padding()
}
