import SwiftUI
import SwiftData
import PhotosUI

struct ProgressPhotoTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]

    @State private var showingAddSheet = false
    @State private var selectedPhoto: ProgressPhoto?

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
                                ProgressPhotoTile(
                                    photo: photo,
                                    onTap: { selectedPhoto = photo },
                                    onDelete: { deletePhoto(photo) }
                                )
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
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddProgressPhotoSheet()
            }
            .fullScreenCover(item: $selectedPhoto) { photo in
                ProgressPhotoFullscreenView(photo: photo, onDelete: {
                    deletePhoto(photo)
                    selectedPhoto = nil
                })
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
        ProgressPhotoImageCache.shared.invalidate(photo)
        try? FileManager.default.removeItem(at: photo.photoURL())
        modelContext.delete(photo)
        try? modelContext.save()
    }
}

// MARK: - Async-load tile (audit M3)

/// Per-photo tile, extracted so `@State var image: UIImage?` and the
/// `.task` that populates it are scoped to the individual row. LazyVGrid
/// recycles tile identity with the photo's persistent ID — scroll
/// performance becomes bounded by the cache hit rate, not the cell
/// count.
private struct ProgressPhotoTile: View {
    let photo: ProgressPhoto
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Placeholder while the JPEG is being decoded off
                    // main. Same slate card as the empty tile plus a
                    // small ProgressView so the user can tell the
                    // difference between "no image" and "loading."
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.slateCard)
                        ProgressView()
                            .tint(Color.slateText)
                    }
                    .frame(height: 180)
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
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .task(id: photo.persistentModelID) {
            // Synchronous cache check happens inside the helper — a
            // warm hit returns before `.task` yields, so scrolled-back-
            // into-view tiles don't flash the placeholder. Cold miss
            // awaits a detached read + decode.
            image = await ProgressPhotoImageCache.shared.image(for: photo)
        }
    }
}

// MARK: - Image cache (audit M3)

/// Decoded-UIImage cache keyed by `PersistentIdentifier`. Sits in front
/// of `ProgressPhoto.loadImage()` so scrolled-past tiles don't re-decode
/// on re-appear. Uses `NSCache` for automatic eviction under memory
/// pressure (no manual tracking).
@MainActor
final class ProgressPhotoImageCache {
    static let shared = ProgressPhotoImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 50
        c.totalCostLimit = 64 * 1024 * 1024  // 64 MB of decoded bitmaps
        return c
    }()

    private func key(for photo: ProgressPhoto) -> NSString {
        // PersistentIdentifier.description is stable per row and
        // survives fetch round-trips. Safe cache key.
        NSString(string: String(describing: photo.persistentModelID))
    }

    func image(for photo: ProgressPhoto) async -> UIImage? {
        let cacheKey = key(for: photo)
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        // Decode off main. Both the disk read and the decode happen in
        // the detached task — this is the expensive work we're avoiding
        // on main during scroll.
        let decoded = await Task.detached(priority: .userInitiated) { [photoURL = photo.photoURL()] () -> UIImage? in
            guard let data = try? Data(contentsOf: photoURL) else { return nil }
            return UIImage(data: data)
        }.value

        if let decoded {
            // Cost ≈ decoded bitmap bytes (w * h * 4 * scale^2). Not
            // perfect because UIImage may lazy-decode, but close enough
            // to keep totalCostLimit meaningful.
            let cost = Int(decoded.size.width * decoded.size.height * 4 * decoded.scale * decoded.scale)
            cache.setObject(decoded, forKey: cacheKey, cost: cost)
        }
        return decoded
    }

    func invalidate(_ photo: ProgressPhoto) {
        cache.removeObject(forKey: key(for: photo))
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
                                    guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                                    // Off-main downscale + JPEG encode (audit M2).
                                    selectedImageData = await ImageCompression.compressedJPEG(from: data)
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
                    Task {
                        // Off-main downscale + JPEG encode (audit M2).
                        selectedImageData = await ImageCompression.compressedJPEG(from: image)
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
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }
            } else {
                ProgressView()
                    .tint(.white)
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
        .task {
            // Reuses the grid's cache — a photo just tapped from the
            // grid is already hot here, no extra read.
            image = await ProgressPhotoImageCache.shared.image(for: photo)
        }
    }
}
