import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @StateObject private var processor = FileProcessor()
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
        .mpeg4Movie,    // MP4
        .movie,         // MOV
        .avi,          // AVI
        .mpeg2Video,   // MPEG-2
        .quickTimeMovie // QuickTime
    ]
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .headerView, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if processor.isProcessing {
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
                } else {
                        ZStack {
                            DropZoneView(
                                isDragging: $isDragging,
                                shouldResize: $shouldResize,
                                maxDimension: $maxDimension,
                                onTap: selectFile
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
    
    private func handleDrop(providers: [NSItemProvider]) {
            guard let provider = providers.first else { return }
            
            // Try each supported type
            for type in supportedTypes {
                if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                    provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                        guard let url = url else {
                            DispatchQueue.main.async {
                                self.alertMessage = "Failed to load file"
                                self.showAlert = true
                            }
                            return
                        }
                        
                        // Create a copy in temporary directory
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension(url.pathExtension)
                        
                        do {
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            
                            DispatchQueue.main.async {
                                self.handleFileSelection(url: tempURL)
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.alertMessage = "Failed to process dropped file"
                                self.showAlert = true
                            }
                        }
                    }
                    return
                }
            }
        }
    
    private func selectFile() {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = supportedTypes
            panel.allowsMultipleSelection = false
            
            if let window = NSApp.windows.first {
                panel.beginSheetModal(for: window) { response in
                    if response == .OK, let url = panel.url {
                        handleFileSelection(url: url)
                    }
                }
            }
    }
    
    private func handleFileSelection(url: URL) {
        Task {
            do {
                let dimensionValue = shouldResize ? Double(maxDimension) ?? 2048 : nil
                print("Debug - Selected max dimension:", dimensionValue ?? "nil")
                
                let settings = CompressionSettings(
                    quality: 0.7,
                    pngCompressionLevel: 6,
                    preserveMetadata: true,
                    maxDimension: dimensionValue != nil ? CGFloat(dimensionValue!) : nil,
                    optimizeForWeb: true
                )
                
                try await processor.processFile(url: url, settings: settings)
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
    
    @MainActor
    private func saveCompressedFile(url: URL, originalName: String) async {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.nameFieldStringValue = "compressed_" + originalName
        panel.allowedContentTypes = [UTType(filenameExtension: url.pathExtension)].compactMap { $0 }
        panel.message = "Choose where to save the compressed file"
        
        guard let window = NSApp.windows.first else { return }
        
        do {
            let response = await panel.beginSheetModal(for: window)
            
            if response == .OK, let saveURL = panel.url {
                do {
                    try FileManager.default.copyItem(at: url, to: saveURL)
                    processor.cleanup()
                } catch {
                    alertMessage = "Failed to save file: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        } catch {
            alertMessage = "Failed to show save dialog"
            showAlert = true
        }
    }
}
