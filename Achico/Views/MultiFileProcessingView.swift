import Foundation
import UniformTypeIdentifiers
import SwiftUI


struct FileProcessingState: Identifiable {
    let id: UUID
    let url: URL
    var progress: Double
    var result: FileProcessor.ProcessingResult?
    var isProcessing: Bool
    var error: Error?
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.progress = 0
        self.result = nil
        self.isProcessing = false
        self.error = nil
    }
}

@MainActor
class MultiFileProcessor: ObservableObject {
    @Published private(set) var files: [FileProcessingState] = []
    @Published private(set) var isProcessingMultiple = false
    private var processingTasks: [UUID: Task<Void, Never>] = [:]
    
    func addFiles(_ urls: [URL]) {
        let newFiles = urls.map { FileProcessingState(url: $0) }
        files.append(contentsOf: newFiles)
        
        // Process each new file individually
        for file in newFiles {
            processFile(with: file.id)
        }
    }
    
    func removeFile(at index: Int) {
        guard index < files.count else { return }
        let fileId = files[index].id
        processingTasks[fileId]?.cancel()
        processingTasks.removeValue(forKey: fileId)
        files.remove(at: index)
    }
    
    func clearFiles() {
        // Cancel all ongoing processing tasks
        for task in processingTasks.values {
            task.cancel()
        }
        processingTasks.removeAll()
        files.removeAll()
    }
    
    private func processFile(with id: UUID) {
        let task = Task {
            await processFileInternal(with: id)
        }
        processingTasks[id] = task
    }
    
    private func processFileInternal(with id: UUID) async {
        guard let index = files.firstIndex(where: { $0.id == id }) else { return }
        guard index < files.count else { return }
        
        let processor = FileProcessor()
        
        // Update the processing state
        files[index].isProcessing = true
        
        do {
            let settings = CompressionSettings(
                quality: 0.7,
                pngCompressionLevel: 6,
                preserveMetadata: true,
                optimizeForWeb: true
            )
            
            try await processor.processFile(url: files[index].url, settings: settings)
            
            guard index < files.count, files[index].id == id else { return }
            
            if let processingResult = processor.processingResult {
                files[index].result = processingResult
                files[index].isProcessing = false
            }
        } catch {
            guard index < files.count, files[index].id == id else { return }
            files[index].error = error
            files[index].isProcessing = false
        }
        
        // Clean up the task
        processingTasks.removeValue(forKey: id)
    }
}

struct MultiFileView: View {
    @ObservedObject var processor: MultiFileProcessor
    @Binding var shouldResize: Bool
    @Binding var maxDimension: String
    let supportedTypes: [UTType]
    
    var body: some View {
        VStack(spacing: 20) {
            List {
                ForEach(Array(processor.files.enumerated()), id: \.element.id) { index, file in
                    FileRow(
                        file: file,
                        onSave: {
                            if let result = file.result {
                                Task {
                                    await saveCompressedFile(url: result.compressedURL, originalName: result.fileName)
                                }
                            }
                        },
                        onRemove: {
                            processor.removeFile(at: index)
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.1))
            .cornerRadius(8)
            
            if !processor.files.isEmpty {
                HStack {
                    Button(action: {
                        processor.clearFiles()
                    }) {
                        Text("Clear All")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 8)
            }
        }
        .padding()
    }
    
    private func saveCompressedFile(url: URL, originalName: String) async {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.nameFieldStringValue = originalName + "compressed_"
        panel.allowedContentTypes = [UTType(filenameExtension: url.pathExtension)].compactMap { $0 }
        panel.message = "Choose where to save the compressed file"
        
        guard let window = NSApp.windows.first else { return }
        
        do {
            let response = await panel.beginSheetModal(for: window)
            
            if response == .OK, let saveURL = panel.url {
                do {
                    try FileManager.default.copyItem(at: url, to: saveURL)
                } catch {
                    print("Failed to save file: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Failed to show save dialog")
        }
    }
}

struct FileRow: View {
    let file: FileProcessingState
    let onSave: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // File icon
            Image(systemName: "doc")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            
            // File name and status
            VStack(alignment: .leading, spacing: 4) {
                Text(file.url.lastPathComponent)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                if let result = file.result {
                    Text("Reduced by \(result.savedPercentage)%")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else if let error = file.error {
                    Text(error.localizedDescription)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                } else if file.isProcessing {
                    Text("Processing...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Progress or actions
            HStack(spacing: 8) {
                if file.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                } else if let result = file.result {
                    Button(action: onSave) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}
