import SwiftUI
import SwiftData

struct DataExportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedFormat: ExportFormat = .json
    @State private var isExporting = false
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false

    var body: some View {
        List {
            Section {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.slateCard)
            } header: {
                Text("Export Format")
                    .foregroundColor(.slateText)
            } footer: {
                Text(selectedFormat == .json ? "JSON exports all data in a single file, suitable for backup." : "CSV exports separate files for workouts, measurements, and weight data.")
                    .foregroundColor(.slateText)
            }

            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Spacer()
                        if isExporting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label("Export \(selectedFormat.rawValue)", systemImage: "square.and.arrow.up")
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.emerald)
                .disabled(isExporting)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.slateBackground)
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }

    private func exportData() {
        isExporting = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch selectedFormat {
            case .json:
                if let url = DataExportService.exportJSON(context: modelContext) {
                    shareItems = [url]
                    showingShareSheet = true
                }
            case .csv:
                let urls = DataExportService.exportCSV(context: modelContext)
                if !urls.isEmpty {
                    shareItems = urls
                    showingShareSheet = true
                }
            }
            isExporting = false
        }
    }
}

// ShareSheet is defined in JournalView.swift
