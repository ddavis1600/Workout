import SwiftUI

struct SetRowView: View {
    let setNumber: Int
    @Binding var reps: String
    @Binding var weight: String
    @Binding var rpe: String
    @Binding var notes: String
    var onDelete: () -> Void

    @State private var showNotes = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Text("\(setNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.emerald)
                    .frame(width: 28)

                TextField("Reps", text: $reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.slateBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)

                TextField("Weight", text: $weight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.slateBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)

                TextField("RPE", text: $rpe)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.slateBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
                    .frame(width: 60)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNotes.toggle()
                    }
                } label: {
                    Image(systemName: notes.isEmpty ? "note.text.badge.plus" : "note.text")
                        .foregroundStyle(notes.isEmpty ? Color.slateText : Color.emerald)
                }

                Button(action: onDelete) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.red)
                }
            }

            if showNotes {
                TextField("Set notes...", text: $notes)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(8)
                    .background(Color.slateBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
                    .padding(.leading, 38)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            if !notes.isEmpty { showNotes = true }
        }
    }
}
