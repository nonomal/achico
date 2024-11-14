import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @StateObject private var processor = FileProcessor()
    @StateObject private var multiProcessor = MultiFileProcessor()
    @State private var isDragging = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var shouldResize = false
    @State private var maxDimension = "2048"
    
    let supportedTypes: [UTType] = [
        .pdf,      // PDF Documents
        .jpeg,     // JPEG Images
        .tiff,     // TIFF Images
        .png,      // PNG Images
        .heic,     // HEIC Images
        .gif,      // GIF Images
        .bmp,      // BMP Images
        .webP,     // WebP Images
        .svg,      // SVG Images
        .rawImage, // RAW Images
        .ico,      // ICO Images
        .mpeg4Movie,    // MP4 Video
        .movie,         // MOV
        .avi,          // AVI
        .mpeg2Video,   // MPEG-2
        .quickTimeMovie, // QuickTime
        .mpeg4Audio,     // MP4 Audio
        .mp3,          // MP3 Audio
        .wav,          // WAV Audio
        .aiff,         // AIFF Audio
    ]
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .headerView, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if processor.isProcessing {
                    // Single file processing view
                    VStack(spacing: 24) {
                        // Progress Circle
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                                .frame(width: 60, height: 60)
                            
                            Circle()
                                .trim(from: 0, to: processor.progress)
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(Int(processor.progress * 100))%")
                                .font(.system(size: 14, weight: .medium))
                        }
                        
                        VStack(spacing: 8) {
                            Text("Compressing File")
                                .font(.system(size: 16, weight: .semibold))
                            Text("This may take a moment...")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: 320)
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .opacity(0.8)
                            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    )
                } else if let result = processor.processingResult {
                    ResultView(result: result) {
                        Task {
                            await saveCompressedFile(url: result.compressedURL, originalName: result.fileName)
                        }
                    } onReset: {
                        processor.cleanup()
                    }
                } else if !multiProcessor.files.isEmpty {
                    MultiFileView(
                        processor: multiProcessor,
                        shouldResize: $shouldResize,
                        maxDimension: $maxDimension,
                        supportedTypes: supportedTypes
                    )
                } else {
                    ZStack {
                        DropZoneView(
                            isDragging: $isDragging,
                            shouldResize: $shouldResize,
                            maxDimension: $maxDimension,
                            onTap: selectFiles
                        )
                        
                        Rectangle()
                            .fill(Color.clear)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay(isDragging ? Color.accentColor.opacity(0.2) : Color.clear)
                            .onDrop(of: supportedTypes, isTargeted: $isDragging) { providers in
                                handleDrop(providers: providers)
                                return true
                            }
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 500)
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = supportedTypes
        panel.allowsMultipleSelection = true
        
        if let window = NSApp.windows.first {
            panel.beginSheetModal(for: window) { response in
                if response == .OK {
                    if panel.urls.count == 1, let url = panel.urls.first {
                        handleFileSelection(url: url)
                    } else if panel.urls.count > 1 {
                        Task { @MainActor in
                            multiProcessor.addFiles(panel.urls)
                        }
                    }
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        if providers.count == 1 {
            guard let provider = providers.first else { return }
            handleSingleFileDrop(provider: provider)
        } else {
            handleMultiFileDrop(providers: providers)
        }
    }
    
    private func handleSingleFileDrop(provider: NSItemProvider) {
        for type in supportedTypes {
            if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                    guard let url = url else {
                        Task { @MainActor in
                            alertMessage = "Failed to load file"
                            showAlert = true
                        }
                        return
                    }
                    
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(url.pathExtension)
                    
                    do {
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        
                        Task { @MainActor in
                            handleFileSelection(url: tempURL)
                        }
                    } catch {
                        Task { @MainActor in
                            alertMessage = "Failed to process dropped file"
                            showAlert = true
                        }
                    }
                }
                return
            }
        }
    }
    
    private func handleMultiFileDrop(providers: [NSItemProvider]) {
        Task {
            var urls: [URL] = []
            
            for provider in providers {
                for type in supportedTypes {
                    if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                        do {
                            let url = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                                provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                                    if let error = error {
                                        continuation.resume(throwing: error)
                                    } else if let url = url {
                                        // Create a temporary copy immediately while the file is still available
                                        let tempURL = FileManager.default.temporaryDirectory
                                            .appendingPathComponent(UUID().uuidString)
                                            .appendingPathExtension(url.pathExtension)
                                        
                                        do {
                                            try FileManager.default.copyItem(at: url, to: tempURL)
                                            continuation.resume(returning: tempURL)
                                        } catch {
                                            continuation.resume(throwing: error)
                                        }
                                    } else {
                                        continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load file"]))
                                    }
                                }
                            }
                            
                            urls.append(url)
                        } catch {
                            print("Failed to process dropped file: \(error.localizedDescription)")
                        }
                        break
                    }
                }
            }
            
            if !urls.isEmpty {
                await MainActor.run {
                    multiProcessor.addFiles(urls)
                }
            }
        }
    }
    
    private func handleFileSelection(url: URL) {
        Task {
            let dimensionValue = shouldResize ? Double(maxDimension) ?? 2048 : nil
            let settings = CompressionSettings(
                quality: 0.7,
                pngCompressionLevel: 6,
                preserveMetadata: true,
                maxDimension: dimensionValue != nil ? CGFloat(dimensionValue!) : nil,
                optimizeForWeb: true
            )
            
            do {
                try await processor.processFile(url: url, settings: settings)
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
    
    private func saveCompressedFile(url: URL, originalName: String) async {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.showsTagField = false
        
        // Get the original file name without any UUID
        let originalURL = URL(fileURLWithPath: originalName)
        let filenameWithoutExt = originalURL.deletingPathExtension().lastPathComponent
        let fileExtension = originalURL.pathExtension
        panel.nameFieldStringValue = "\(filenameWithoutExt)_compressed.\(fileExtension)"
        
        panel.allowedContentTypes = [UTType(filenameExtension: url.pathExtension)].compactMap { $0 }
        panel.message = "Choose where to save the compressed file"
        
        guard let window = NSApp.windows.first else { return }
        
        let response = await panel.beginSheetModal(for: window)
        
        if response == .OK, let saveURL = panel.url {
            do {
                try FileManager.default.copyItem(at: url, to: saveURL)
                processor.cleanup()  // Only for ContentView
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to save file: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}
