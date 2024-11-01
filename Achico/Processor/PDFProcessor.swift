import Foundation
import PDFKit
import UniformTypeIdentifiers
import AppKit

class PDFProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var processingResult: ProcessingResult?
    private var tempFiles: [URL] = []
    
    struct ProcessingResult {
        let originalSize: Int64
        let compressedSize: Int64
        let compressedURL: URL
        let fileName: String
        
        var savedPercentage: Int {
            guard originalSize > 0 else { return 0 }
            let percentage = Int(((Double(originalSize) - Double(compressedSize)) / Double(originalSize)) * 100)
            return max(0, percentage) // Ensure percentage is never negative
        }
    }
    
    deinit {
        cleanupTempFiles()
    }
    
    private func cleanupTempFiles() {
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        tempFiles.removeAll()
    }
    
    @MainActor
    func processPDF(url: URL) async throws {
        isProcessing = true
        progress = 0
        processingResult = nil
        
        cleanupTempFiles()
        
        do {
            let originalSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
            
            // Create a copy of the input file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("compressed_\(UUID().uuidString)")
                .appendingPathExtension("pdf")
            
            try FileManager.default.copyItem(at: url, to: tempURL)
            tempFiles.append(tempURL)
            
            guard let document = PDFDocument(url: url) else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load PDF"])
            }
            
            // Create new document
            let newDocument = PDFDocument()
            
            for i in 0..<document.pageCount {
                autoreleasepool {
                    if let page = document.page(at: i) {
                        // Try to compress the page, if fails, use original
                        if let compressedPage = try? compressPage(page) {
                            newDocument.insert(compressedPage, at: i)
                        } else {
                            newDocument.insert(page, at: i)
                        }
                    }
                }
                
                progress = Double(i + 1) / Double(document.pageCount)
            }
            
            // Save the document
            newDocument.write(to: tempURL)
            
            let compressedSize = try FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64 ?? 0
            
            // Always create a result, even if compression didn't reduce size
            processingResult = ProcessingResult(
                originalSize: originalSize,
                compressedSize: compressedSize,
                compressedURL: tempURL,
                fileName: url.lastPathComponent
            )
            
        } catch {
            isProcessing = false
            throw error
        }
        
        isProcessing = false
        progress = 1.0
    }
    
    private func compressPage(_ page: PDFPage) throws -> PDFPage? {
        let pageRect = page.bounds(for: .mediaBox)
        
        // Create NSImage from page
        let image = NSImage(size: pageRect.size)
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            page.draw(with: .mediaBox, to: context)
        }
        image.unlockFocus()
        
        // Compress using JPEG compression
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let compressedData = bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.5]
              ),
              let compressedImage = NSImage(data: compressedData) else {
            return nil
        }
        
        return PDFPage(image: compressedImage)
    }
    
    func cleanup() {
        cleanupTempFiles()
        processingResult = nil
    }
}
