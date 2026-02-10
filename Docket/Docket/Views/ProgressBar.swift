import SwiftUI

/// Minimal thin progress bar — just a colored fill on a grey track. No text.
struct ProgressBar: View {
    let progress: Double // 0.0 - 100.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.gray.opacity(0.15))
                
                // Fill
                if progress > 0 {
                    Capsule()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * min(progress / 100, 1.0))
                }
            }
        }
        .frame(height: 2)
    }
    
    private var progressColor: Color {
        switch progress {
        case 0..<25: return .gray.opacity(0.5)
        case 25..<75: return .blue.opacity(0.5)
        case 75..<100: return .blue
        default: return .green
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ProgressBar(progress: 0)
        ProgressBar(progress: 35)
        ProgressBar(progress: 75)
        ProgressBar(progress: 100)
    }
    .padding()
}
