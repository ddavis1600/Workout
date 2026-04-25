import SwiftUI
import SwiftData
import PhotosUI

struct ProgressPhotoTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]

    @State private var showingAddSheet = false
    @State private var selectedPhoto: ProgressPhoto?
    // AUDIT H5
    @State private var photoPendingDelete: ProgressPhoto? = nil

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                if photos.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(photos) { photo in
                                photoTile(photo)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Progress Photos")
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.emerald)
                    }
                    .accessibilityLabel("Add progress photo")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddProgressPhotoSheet()
            }
            .fullScreenCover(item: $selectedPhoto) { photo in
                // Fullscreen viewer dismisses itself, then we let the
                // parent's `confirmationDialog` below handle the actual
                // delete. Trying to confirm INSIDE the fullScreenCover
                // races with its dismissal animation.
                ProgressPhotoFullscreenView(photo: photo, onDelete: {
                    selectedPhoto = nil
                    photoPendingDelete = photo
                })
            }
            .confirmationDialog(
                "Delete progress photo?",
                isPresented: Binding(
                    get: { photoPendingDelete != nil },
                    set: { if !$0 { photoPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let p = photoPendingDelete {
                        deletePhoto(p)
                    }
                    photoPendingDelete = nil
                }
                Button("Cancel", role: .cancel) { photoPendingDelete = nil }
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    // MARK: - Photo Tile

    private func photoTile(_ photo: ProgressPhoto) -> some View {
        Button {
            selectedPhoto = photo
        } label: {
            ZStack(alignment: .bottomLeading) {
                if let image = photo.loadImage() {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.slateCard)
                        .frame(height: 180)
                    Image(systemName: "photo")
                        .foregroundStyle(Color.slateText)
                }

                // Date overlay
                VStack(alignment: .leading, spacing: 2) {
                    Text(photo.date.formatted(as: "MMM d, yyyy"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    if !photo.caption.isEmpty {
                        Text(photo.caption)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .padding(8)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.6)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                photoPendingDelete = photo
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52))
                .foregroundStyle(Color.slateText)
            Text("No progress photos yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.ink)
            Text("Tap + to add your first progress photo")
                .font(.subheadline)
                .foregroundStyle(Color.slateText)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Delete

    private func deletePhoto(_ photo: ProgressPhoto) {
        try? FileManager.default.removeItem(at: photo.photoURL())
        modelContext.delete(photo)
        try? modelContext.save()
    }
}

// MARK: - Add Sheet

struct AddProgressPhotoSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var caption = ""
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showingCamera = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Photo preview or picker
                        if let data = selectedImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.slateCard)
                                .frame(height: 200)
                                .overlay {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Color.slateText)
                                }
                        }

                        HStack(spacing: 12) {
                            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                                Label("Library", systemImage: "photo.on.rectangle")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.slateCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .onChange(of: photoPickerItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let ui = UIImage(data: data),
                                       let jpeg = ui.jpegData(compressionQuality: 0.8) {
                                        selectedImageData = jpeg
                                    }
                                }
                            }

                            Button {
                                showingCamera = true
                            } label: {
                                Label("Camera", systemImage: "camera.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.slateCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(.emerald)
                            .foregroundStyle(Color.ink)
                            .padding(12)
                            .background(Color.slateCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        TextField("Caption (optional)", text: $caption)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.slateCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(Color.ink)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.slateText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let data = selectedImageData else { return }
                        ProgressPhoto.save(imageData: data, date: date, caption: caption, context: modelContext)
                        dismiss()
                    }
                    .disabled(selectedImageData == nil)
                    .foregroundStyle(Color.emerald)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingCamera) {
                MealCameraView { image in
                    if let jpeg = image.jpegData(compressionQuality: 0.8) {
                        selectedImageData = jpeg
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Fullscreen

struct ProgressPhotoFullscreenView: View {
    let photo: ProgressPhoto
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = photo.loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Image unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, Color.black.opacity(0.5))
                    }
                    .padding()

                    Spacer()

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.title)
                            .foregroundStyle(.red, Color.black.opacity(0.5))
                    }
                    .padding()
                }
                Spacer()

                // Date + caption
                VStack(alignment: .leading, spacing: 4) {
                    Text(photo.date.formatted(as: "EEEE, MMM d, yyyy"))
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    if !photo.caption.isEmpty {
                        Text(photo.caption)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}
