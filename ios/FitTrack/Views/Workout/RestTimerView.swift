import SwiftUI
import AudioToolbox

struct RestTimerView: View {
    let duration: Int
    var onDismiss: () -> Void

    @State private var remaining: Int
    @State private var timer: Timer?
    @State private var isFinished = false

    init(duration: Int, onDismiss: @escaping () -> Void) {
        self.duration = duration
        self.onDismiss = onDismiss
        self._remaining = State(initialValue: duration)
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return Double(duration - remaining) / Double(duration)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Rest Timer")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    stopTimer()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.slateText)
                }
            }

            ZStack {
                Circle()
                    .stroke(Color.slateBorder, lineWidth: 6)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(isFinished ? Color.green : Color.emerald, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)

                VStack(spacing: 2) {
                    Text(formattedTime)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(isFinished ? .green : .white)
                    if isFinished {
                        Text("Done!")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
            }

            HStack(spacing: 20) {
                Button {
                    remaining = min(remaining + 15, 600)
                } label: {
                    Text("+15s")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.emerald)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.slateBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    stopTimer()
                    onDismiss()
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.slateBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(20)
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.emerald.opacity(0.3), lineWidth: 1)
        )
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private var formattedTime: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remaining > 0 {
                remaining -= 1
            } else {
                isFinished = true
                stopTimer()
                AudioServicesPlaySystemSound(1007)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
