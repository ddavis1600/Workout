import SwiftUI

struct SetRowView: View {
    let setNumber: Int
    @Binding var reps: String
    @Binding var weight: String
    @Binding var rpe: String
    var onDelete: () -> Void

    var body: some View {
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

            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }
}
