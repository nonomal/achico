import Foundation
import PDFKit
import UniformTypeIdentifiers
import AppKit

class PDFProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var processingResult: ProcessingResult?
    
    private let processingQueue = DispatchQueue(label: "com.achico.pdfprocessing", qos: .userInitiated)
    private let cacheManager = PDFCacheManager.shared
    
    struct ProcessingResult {
        let originalSize: Int64
        let compressedSize: Int64
        let compressedURL: URL
        let fileName: String
        
        var savedPercentage: Int {
            guard originalSize > 0 else { return 0 }
            let percentage = Int(((Double(originalSize) - Double(compressedSize)) / Double(originalSize)) * 100)
            return max(0, percentage)
        }
    }
    
    deinit {
        cleanup()
    }
    
    @MainActor
    func processPDF(url: URL) async throws {
        isProcessing = true
        progress = 0
        processingResult = nil
        
        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                processingQueue.async {
                    do {
                        let result = try self.processInBackground(url: url)
                        DispatchQueue.main.async {
                            continuation.resume(returning: result)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
            
            self.processingResult = result
            
        } catch {
            isProcessing = false
            throw error
        }
        
        isProcessing = false
        progress = 1.0
    }
    
    private func processInBackground(url: URL) throws -> ProcessingResult {
        let originalSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        
        // Create output file in cache directory
        let tempURL = try cacheManager.createTemporaryURL(for: url.lastPathComponent)
        
        guard let document = PDFDocument(url: url) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load PDF"])
        }
        
        // Create new document
        let newDocument = PDFDocument()
        let totalPages = document.pageCount
        
        for i in 0..<totalPages {
            autoreleasepool {
                if let page = document.page(at: i) {
                    if let compressedPage = try? compressPage(page) {
                        newDocument.insert(compressedPage, at: i)
                    } else {
                        newDocument.insert(page, at: i)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.progress = Double(i + 1) / Double(totalPages)
            }
        }
        
        // Save the document
        newDocument.write(to: tempURL)
        
        let compressedSize = try FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64 ?? 0
        
        return ProcessingResult(
            originalSize: originalSize,
            compressedSize: compressedSize,
            compressedURL: tempURL,
            fileName: url.lastPathComponent
        )
    }
    
    private func compressPage(_ page: PDFPage) throws -> PDFPage? {
        let pageRect = page.bounds(for: .mediaBox)
        
        let image = NSImage(size: pageRect.size)
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            page.draw(with: .mediaBox, to: context)
        }
        image.unlockFocus()
        
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
        processingResult = nil
        cacheManager.cleanupOldFiles()
    }
}
