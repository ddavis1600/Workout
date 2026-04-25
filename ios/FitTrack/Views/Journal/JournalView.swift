import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

// MARK: - Journal List View

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var showingNewEntry = false
    @State private var entryToEdit: JournalEntry?
    @State private var entryToDelete: JournalEntry?
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    emptyState
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(entries) { entry in
                        NavigationLink(destination: JournalDetailView(entry: entry)) {
                            journalRow(entry)
                        }
                        .listRowBackground(Color.slateBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                entryToDelete = entry
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                entryToEdit = entry
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.emerald)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.slateBackground)
            .toolbarBackground(Color.slateBackground, for: .navigationBar)
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.emerald)
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NewJournalEntryView()
            }
            .sheet(item: $entryToEdit) { entry in
                NewJournalEntryView(entry: entry)
            }
            .alert("Delete Entry?", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let entry = entryToDelete {
                        performDelete(entry)
                    }
                    entryToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    entryToDelete = nil
                }
            } message: {
                Text("This entry will be permanently deleted.")
            }
        }
    }

    private func performDelete(_ entry: JournalEntry) {
        if let url = entry.audioURL {
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(entry)
        try? modelContext.save()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.slateText)
            Text("No journal entries yet")
                .font(.title3)
                .foregroundColor(Color.ink)
            Text("Tap + to write your first entry")
                .font(.subheadline)
                .foregroundColor(.slateText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func journalRow(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !entry.mood.isEmpty {
                    Text(entry.mood)
                        .font(.title2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title.isEmpty ? "Untitled" : entry.title)
                        .font(.body.weight(.medium))
                        .foregroundColor(Color.ink)
                        .lineLimit(1)
                    Text(entry.date.formatted(as: "MMM d, yyyy 'at' h:mm a"))
                        .font(.caption)
                        .foregroundColor(.slateText)
                }
                Spacer()
                HStack(spacing: 6) {
                    if entry.photoData != nil {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundColor(.slateText)
                    }
                    if entry.audioFileName != nil {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundColor(.slateText)
                    }
                }
            }

            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.subheadline)
                    .foregroundColor(.slateText)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color.slateCard)
        .cornerRadius(12)
    }
}

// MARK: - New Journal Entry

struct NewJournalEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let entryToEdit: JournalEntry?
    private let initialAudioFileName: String?

    @State private var title: String
    @State private var content: String
    @State private var selectedMood: String
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var audioRecorder: AVAudioRecorder? = nil
    @State private var isRecording = false
    @State private var audioFileName: String? = nil
    @State private var audioDuration: Double? = nil
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var isPlaying = false
    @State private var recordingSeconds: Int = 0
    @State private var recordingTimer: Timer? = nil

    private let moods = ["", "\u{1F60A}", "\u{1F4AA}", "\u{1F60C}", "\u{1F914}", "\u{1F622}", "\u{1F621}", "\u{1F634}", "\u{1F525}", "\u{2764}\u{FE0F}", "\u{2B50}"]

    init(entry: JournalEntry? = nil) {
        self.entryToEdit = entry
        self.initialAudioFileName = entry?.audioFileName
        _title = State(initialValue: entry?.title ?? "")
        _content = State(initialValue: entry?.content ?? "")
        _selectedMood = State(initialValue: entry?.mood ?? "")
        _photoData = State(initialValue: entry?.photoData)
        _audioFileName = State(initialValue: entry?.audioFileName)
        _audioDuration = State(initialValue: entry?.audioDuration)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.slateBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Mood picker
                        moodSection

                        // Title
                        TextField("Title (optional)", text: $title)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.slateCard)
                            .cornerRadius(12)
                            .foregroundColor(Color.ink)

                        // Content
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Entry")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.slateText)

                            TextEditor(text: $content)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 150)
                                .padding(12)
                                .background(Color.slateCard)
                                .cornerRadius(12)
                                .foregroundColor(Color.ink)
                        }

                        // Photo
                        photoSection

                        // Audio
                        audioSection
                    }
                    .padding()
                }
            }
            .navigationTitle(entryToEdit == nil ? "New Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanupUnsavedAudio()
                        dismiss()
                    }
                    .foregroundColor(.slateText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .foregroundColor(.emerald)
                    .disabled(title.isEmpty && content.isEmpty && photoData == nil && audioFileName == nil)
                }
            }
        }
        .presentationDetents([.large])
        .onDisappear {
            stopRecording()
            stopPlaying()
        }
    }

    // MARK: - Mood Section

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How are you feeling?")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.slateText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(moods, id: \.self) { mood in
                        Button {
                            selectedMood = mood
                        } label: {
                            if mood.isEmpty {
                                Image(systemName: "xmark.circle")
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedMood.isEmpty ? Color.emerald.opacity(0.2) : Color.slateCard)
                                    .foregroundColor(selectedMood.isEmpty ? .emerald : .slateText)
                                    .cornerRadius(10)
                            } else {
                                Text(mood)
                                    .font(.title)
                                    .frame(width: 44, height: 44)
                                    .background(selectedMood == mood ? Color.emerald.opacity(0.2) : Color.slateCard)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedMood == mood ? Color.emerald : Color.clear, lineWidth: 2)
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photo")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.slateText)

            if let data = photoData, let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        photoData = nil
                        selectedPhotoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .padding(8)
                }
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label(photoData == nil ? "Add Photo" : "Change Photo", systemImage: "camera.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.emerald)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.slateCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.emerald.opacity(0.3), lineWidth: 1)
                    )
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                    // Off-main downscale + JPEG encode (audit M2).
                    photoData = await ImageCompression.compressedJPEG(from: data) ?? data
                }
            }
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Voice Note")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.slateText)

            if let _ = audioFileName {
                // Playback controls
                HStack(spacing: 16) {
                    Button {
                        if isPlaying { stopPlaying() } else { playAudio() }
                    } label: {
                        Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.emerald)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice Note")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(Color.ink)
                        if let dur = audioDuration {
                            Text(formatDuration(dur))
                                .font(.caption)
                                .foregroundColor(.slateText)
                        }
                    }

                    Spacer()

                    Button {
                        deleteAudio()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.slateCard)
                .cornerRadius(12)
            } else {
                // Record button
                Button {
                    if isRecording { stopRecording() } else { startRecording() }
                } label: {
                    HStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title2)
                        if isRecording {
                            Text("Recording... \(formatDuration(Double(recordingSeconds)))")
                                .font(.subheadline.weight(.medium))
                        } else {
                            Text("Record Voice Note")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    .foregroundStyle(isRecording ? Color.red : Color.emerald)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.slateCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke((isRecording ? Color.red : Color.emerald).opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Audio Recording

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }

        let fileName = "journal_\(UUID().uuidString).m4a"
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName) else { return }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingSeconds = 0
            audioFileName = fileName

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                recordingSeconds += 1
            }
        } catch {
            print("Recording failed: \(error)")
        }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        guard let recorder = audioRecorder, recorder.isRecording else {
            isRecording = false
            return
        }

        audioDuration = recorder.currentTime
        recorder.stop()
        audioRecorder = nil
        isRecording = false
    }

    private func playAudio() {
        guard let name = audioFileName,
              let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(name) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlaying = true

            // Stop when finished
            DispatchQueue.main.asyncAfter(deadline: .now() + (audioDuration ?? 5)) {
                isPlaying = false
            }
        } catch {
            print("Playback failed: \(error)")
        }
    }

    private func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    private func deleteAudio() {
        stopPlaying()
        if let name = audioFileName,
           let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(name) {
            try? FileManager.default.removeItem(at: url)
        }
        audioFileName = nil
        audioDuration = nil
    }

    private func cleanupUnsavedAudio() {
        stopRecording()
        // In edit mode, only delete audio that was newly recorded — not the entry's original file
        if audioFileName != initialAudioFileName {
            deleteAudio()
        }
    }

    // MARK: - Save

    private func saveEntry() {
        stopRecording()
        if let entry = entryToEdit {
            entry.title = title
            entry.content = content
            entry.mood = selectedMood
            entry.photoData = photoData
            entry.audioFileName = audioFileName
            entry.audioDuration = audioDuration
            entry.updatedAt = Date()
        } else {
            let entry = JournalEntry(
                date: Date(),
                title: title,
                content: content,
                mood: selectedMood,
                photoData: photoData,
                audioFileName: audioFileName,
                audioDuration: audioDuration
            )
            modelContext.insert(entry)
        }
        try? modelContext.save()
        dismiss()
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Journal Detail View

struct JournalDetailView: View {
    let entry: JournalEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var showingExport = false
    @State private var exportURL: URL?
    @State private var showingEditEntry = false
    @State private var showingDeleteAlert = false

    var body: some View {
        ZStack {
            Color.slateBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        if !entry.mood.isEmpty {
                            Text(entry.mood)
                                .font(.largeTitle)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title.isEmpty ? "Untitled" : entry.title)
                                .font(.title2.weight(.bold))
                                .foregroundColor(Color.ink)
                            Text(entry.date.formatted(as: "EEEE, MMM d, yyyy 'at' h:mm a"))
                                .font(.subheadline)
                                .foregroundColor(.slateText)
                        }
                    }

                    // Photo
                    if let data = entry.photoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Content
                    if !entry.content.isEmpty {
                        Text(entry.content)
                            .font(.body)
                            .foregroundColor(Color.ink)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.slateCard)
                            .cornerRadius(12)
                    }

                    // Audio playback
                    if entry.audioFileName != nil {
                        HStack(spacing: 16) {
                            Button {
                                if isPlaying { stopPlaying() } else { playAudio() }
                            } label: {
                                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.emerald)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Voice Note")
                                    .font(.headline)
                                    .foregroundColor(Color.ink)
                                if let dur = entry.audioDuration {
                                    Text(formatDuration(dur))
                                        .font(.subheadline)
                                        .foregroundColor(.slateText)
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.slateCard)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditEntry = true
                    } label: {
                        Label("Edit Entry", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                    Divider()
                    Button {
                        exportAsPDF()
                    } label: {
                        Label("Export as PDF", systemImage: "doc.richtext")
                    }
                    Button {
                        exportAsText()
                    } label: {
                        Label("Export as Text", systemImage: "doc.plaintext")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.emerald)
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $showingEditEntry) {
            NewJournalEntryView(entry: entry)
        }
        .alert("Delete Entry?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This entry will be permanently deleted.")
        }
        .onDisappear {
            stopPlaying()
        }
    }

    private func deleteEntry() {
        if let url = entry.audioURL {
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(entry)
        try? modelContext.save()
        dismiss()
    }

    private func playAudio() {
        guard let url = entry.audioURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlaying = true
            DispatchQueue.main.asyncAfter(deadline: .now() + (entry.audioDuration ?? 5)) {
                isPlaying = false
            }
        } catch {
            print("Playback failed: \(error)")
        }
    }

    private func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    // MARK: - Export as PDF

    private func exportAsPDF() {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            var yPos: CGFloat = 40

            // Title
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let titleStr = entry.title.isEmpty ? "Journal Entry" : entry.title
            let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.black]
            titleStr.draw(at: CGPoint(x: 40, y: yPos), withAttributes: titleAttr)
            yPos += 36

            // Date
            let dateFont = UIFont.systemFont(ofSize: 14)
            let dateStr = entry.date.formatted(as: "EEEE, MMMM d, yyyy 'at' h:mm a")
            dateStr.draw(at: CGPoint(x: 40, y: yPos), withAttributes: [.font: dateFont, .foregroundColor: UIColor.gray])
            yPos += 24

            // Mood
            if !entry.mood.isEmpty {
                let moodStr = "Mood: \(entry.mood)"
                moodStr.draw(at: CGPoint(x: 40, y: yPos), withAttributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.black])
                yPos += 28
            }

            yPos += 8

            // Content
            if !entry.content.isEmpty {
                let contentFont = UIFont.systemFont(ofSize: 14)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 4
                let contentAttr: [NSAttributedString.Key: Any] = [
                    .font: contentFont,
                    .foregroundColor: UIColor.darkGray,
                    .paragraphStyle: paragraphStyle
                ]
                let contentRect = CGRect(x: 40, y: yPos, width: 532, height: 400)
                entry.content.draw(in: contentRect, withAttributes: contentAttr)
                yPos += min(400, entry.content.boundingRect(with: CGSize(width: 532, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: contentAttr, context: nil).height) + 20
            }

            // Photo
            if let photoData = entry.photoData, let image = UIImage(data: photoData) {
                let maxWidth: CGFloat = 532
                let maxHeight: CGFloat = 300
                let scale = min(maxWidth / image.size.width, maxHeight / image.size.height, 1.0)
                let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

                if yPos + drawSize.height > 752 {
                    context.beginPage()
                    yPos = 40
                }
                image.draw(in: CGRect(x: 40, y: yPos, width: drawSize.width, height: drawSize.height))
                yPos += drawSize.height + 16
            }

            // Audio note indicator
            if entry.audioFileName != nil {
                if yPos > 740 {
                    context.beginPage()
                    yPos = 40
                }
                let audioStr = "Voice note attached (\(formatDuration(entry.audioDuration ?? 0)))"
                audioStr.draw(at: CGPoint(x: 40, y: yPos), withAttributes: [.font: UIFont.italicSystemFont(ofSize: 12), .foregroundColor: UIColor.gray])
            }
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Journal_\(entry.date.formatted(as: "yyyy-MM-dd")).pdf")
        try? data.write(to: tempURL)
        exportURL = tempURL
        showingExport = true
    }

    // MARK: - Export as Text

    private func exportAsText() {
        var text = ""
        text += "# \(entry.title.isEmpty ? "Journal Entry" : entry.title)\n"
        text += "Date: \(entry.date.formatted(as: "EEEE, MMMM d, yyyy 'at' h:mm a"))\n"
        if !entry.mood.isEmpty {
            text += "Mood: \(entry.mood)\n"
        }
        text += "\n"
        text += entry.content
        if entry.audioFileName != nil {
            text += "\n\n[Voice note: \(formatDuration(entry.audioDuration ?? 0))]"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Journal_\(entry.date.formatted(as: "yyyy-MM-dd")).md")
        try? text.write(to: tempURL, atomically: true, encoding: .utf8)
        exportURL = tempURL
        showingExport = true
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
