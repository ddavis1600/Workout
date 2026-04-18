import SwiftUI

struct BodyStatsForm: View {
    @Binding var weight: String
    @Binding var height: String
    @Binding var age: String
    @Binding var gender: String
    @Binding var activityLevel: String
    var unitSystem: String

    private var weightLabel: String {
        unitSystem == "imperial" ? "Weight (lbs)" : "Weight (kg)"
    }

    private var heightLabel: String {
        unitSystem == "imperial" ? "Height (in)" : "Height (cm)"
    }

    static let genderOptions = ["male", "female"]

    static let activityOptions: [(value: String, label: String)] = [
        ("sedentary", "Sedentary"),
        ("light", "Lightly Active"),
        ("moderate", "Moderately Active"),
        ("active", "Very Active"),
        ("very_active", "Extra Active"),
    ]

    var body: some View {
        VStack(spacing: 14) {
            sectionHeader("Body Stats")

            labeledTextField(label: weightLabel, text: $weight, keyboard: .decimalPad)
            labeledTextField(label: heightLabel, text: $height, keyboard: .decimalPad)
            labeledTextField(label: "Age", text: $age, keyboard: .numberPad)

            // Gender picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Gender")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
                Picker("Gender", selection: $gender) {
                    Text("Male").tag("male")
                    Text("Female").tag("female")
                }
                .pickerStyle(.segmented)
            }

            // Activity level picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Activity Level")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
                Picker("Activity Level", selection: $activityLevel) {
                    ForEach(Self.activityOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .pickerStyle(.menu)
                .tint(.emerald)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.slateBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledTextField(label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.slateText)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.slateBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Color.ink)
        }
    }
}
