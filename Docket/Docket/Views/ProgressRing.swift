import SwiftUI

/// Minimal circular progress indicator — same size as the standard checkbox (22pt).
/// Shows the number inside (no % sign). Green checkmark at 100%.
struct ProgressRing: View {
    let progress: Double // 0.0 - 100.0
    var lineWidth: CGFloat = 2
    
    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.gray.opacity(0.25), lineWidth: lineWidth)
            
            // Progress arc
            Circle()
                .trim(from: 0, to: min(progress / 100, 1.0))
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Center content: checkmark at 100%, number otherwise
            if progress >= 100 {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
            } else if progress > 0 {
                Text("\(Int(progress))")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: 22, height: 22)
    }
    
    private var progressColor: Color {
        switch progress {
        case 0..<25: return .gray.opacity(0.6)
        case 25..<75: return .blue.opacity(0.6)
        case 75..<100: return .blue
        default: return .green
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        ProgressRing(progress: 0)
        ProgressRing(progress: 5)
        ProgressRing(progress: 35)
        ProgressRing(progress: 75)
        ProgressRing(progress: 100)
    }
    .padding()
}
