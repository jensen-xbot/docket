import SwiftUI

/// Minimal inline progress slider — just the slider control, nothing else.
struct ProgressSlider: View {
    @Binding var progress: Double
    var onComplete: (() -> Void)? = nil
    
    var body: some View {
        Slider(value: $progress, in: 0...100, step: 5)
            .tint(.blue)
            .padding(.vertical, 4)
    }
}

#Preview {
    ProgressSlider(progress: .constant(35))
        .padding(.horizontal, 16)
}
