import SwiftUI
import SwiftData
import PhotosUI

struct MealSectionView: View {
    let mealType: String
    let entries: [DiaryEntry]
    let date: Date
    var onAdd: (Food, Double) -> Void
    var onDelete: (DiaryEntry) -> Void

    @State private var showingFoodSearch = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var fullscreenPhoto: UIImage?
    @State private var showFullscreen = false
    @State private var showPhotoOptions = false

    private var mealCalories: Double {
        entries.reduce(0) { $0 + $1.totalCalories }
    }

    // FileManager key for this meal's photo
    private var photoKey: String {
        let dateStr = date.formatted(as: "yyyy-MM-dd")
        return "meal_photo_\(mealType)_\(dateStr).jpg"
    }

    private var savedPhoto: UIImage? {
        let url = photoURL(for: photoKey)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
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

                // Camera icon
                Button {
                    showPhotoOptions = true
                } label: {
                    Image(systemName: savedPhoto != nil ? "camera.fill" : "camera")
                        .font(.subheadline)
                        .foregroundStyle(savedPhoto != nil ? Color.emerald : Color.slateText)
                }
                .padding(.leading, 8)
                .confirmationDialog("Meal Photo", isPresented: $showPhotoOptions) {
                    Button("Choose from Library") { showingImagePicker = true }
                    Button("Take Photo") { showingCamera = true }
                    if savedPhoto != nil {
                        Button("Remove Photo", role: .destructive) { deletePhoto() }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }

            // Photo thumbnail
            if let photo = savedPhoto {
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
                                deletePhoto()
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
                showingFoodSearch = true
            } label: {
                Label("Add Food", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.emerald)
            }
            .sheet(isPresented: $showingFoodSearch) {
                FoodSearchView { food, servings in
                    onAdd(food, servings)
                }
            }
        }
        .padding()
        .background(Color.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.slateBorder, lineWidth: 1)
        )
        // Photo library picker
        .photosPicker(isPresented: $showingImagePicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data),
                   let jpeg = uiImage.jpegData(compressionQuality: 0.75) {
                    savePhoto(jpeg)
                }
            }
        }
        // Camera
        .sheet(isPresented: $showingCamera) {
            MealCameraView { image in
                if let jpeg = image.jpegData(compressionQuality: 0.75) {
                    savePhoto(jpeg)
                }
            }
        }
        // Fullscreen viewer
        .fullScreenCover(isPresented: $showFullscreen) {
            if let photo = fullscreenPhoto {
                MealPhotoFullscreenView(image: photo)
            }
        }
    }

    // MARK: - Photo persistence

    private func photoURL(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MealPhotos", isDirectory: true)
            .appendingPathComponent(filename)
    }

    private func savePhoto(_ data: Data) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MealPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(photoKey)
        try? data.write(to: url)
    }

    private func deletePhoto() {
        let url = photoURL(for: photoKey)
        try? FileManager.default.removeItem(at: url)
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
