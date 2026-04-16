import SwiftUI
import SwiftData

struct MealSectionView: View {
    let mealType: String
    let entries: [DiaryEntry]
    let date: Date
    var onAdd: (Food, Double) -> Void
    var onDelete: (DiaryEntry) -> Void

    // Callbacks so the parent (DiaryView) owns all sheet/picker presentation.
    // Having multiple .sheet modifiers on sibling List rows causes SwiftUI presentation
    // conflicts — the reliable fix is a single sheet at the NavigationStack level.
    var onAddFoodTapped: () -> Void
    var onCameraTapped: () -> Void
    var onLibraryTapped: () -> Void
    var onDeletePhoto: () -> Void

    // Incremented by DiaryView after saving/deleting a photo so this view reloads from disk.
    var photoLoadToken: UUID

    @State private var mealPhoto: UIImage? = nil
    @State private var fullscreenPhoto: UIImage?
    @State private var showFullscreen = false
    @State private var showPhotoOptions = false

    private var mealCalories: Double {
        entries.reduce(0) { $0 + $1.totalCalories }
    }

    private var photoKey: String {
        let dateStr = date.formatted(as: "yyyy-MM-dd")
        return "meal_photo_\(mealType)_\(dateStr).jpg"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text(mealType.capitalized)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(mealCalories)) kcal")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.emerald)

                Button {
                    showPhotoOptions = true
                } label: {
                    Image(systemName: mealPhoto != nil ? "camera.fill" : "camera")
                        .font(.subheadline)
                        .foregroundStyle(mealPhoto != nil ? Color.emerald : Color.slateText)
                }
                .padding(.leading, 8)
                .buttonStyle(.plain)
            }

            // Photo thumbnail
            if let photo = mealPhoto {
                Button {
                    fullscreenPhoto = photo
                    showFullscreen = true
                } label: {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                onDeletePhoto()
                                mealPhoto = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white, Color.black.opacity(0.5))
                            }
                            .padding(6)
                        }
                }
            }

            if entries.isEmpty {
                Text("No food logged")
                    .font(.caption)
                    .foregroundStyle(Color.slateText)
                    .padding(.vertical, 4)
            } else {
                ForEach(entries, id: \.self) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.food?.name ?? "Unknown")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Text("\(entry.servings, specifier: "%.1f") serving\(entry.servings == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(Color.slateText)
                        }
                        Spacer()
                        Text("\(Int(entry.totalCalories)) kcal")
                            .font(.subheadline)
                            .foregroundStyle(Color.slateText)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDelete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Divider().overlay(Color.slateBorder)

            Button {
                onAddFoodTapped()
            } label: {
                Label("Add Food", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.emerald)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.slateBorder, lineWidth: 1)
        )
        .confirmationDialog("Meal Photo", isPresented: $showPhotoOptions) {
            Button("Choose from Library") {
                onLibraryTapped()
            }
            Button("Take Photo") {
                onCameraTapped()
            }
            if mealPhoto != nil {
                Button("Remove Photo", role: .destructive) {
                    onDeletePhoto()
                    mealPhoto = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Fullscreen viewer is its own presentation type — no conflict with parent's .sheet
        .fullScreenCover(isPresented: $showFullscreen) {
            if let photo = fullscreenPhoto {
                MealPhotoFullscreenView(image: photo)
            }
        }
        .onAppear { loadPhoto() }
        .onChange(of: photoLoadToken) { _, _ in loadPhoto() }
    }

    // MARK: - Photo persistence (read only — parent owns writes)

    private func loadPhoto() {
        let url = photoURL(for: photoKey)
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            mealPhoto = image
        } else {
            mealPhoto = nil
        }
    }

    private func photoURL(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MealPhotos", isDirectory: true)
            .appendingPathComponent(filename)
    }
}

// MARK: - Camera UIViewControllerRepresentable

struct MealCameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: MealCameraView
        init(_ parent: MealCameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Fullscreen viewer

struct MealPhotoFullscreenView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, Color.black.opacity(0.5))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}
