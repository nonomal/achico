import Foundation
import PDFKit
import UniformTypeIdentifiers
import AppKit
import CoreGraphics

class FileProcessor: ObservableObject {
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var processingResult: ProcessingResult?
    
    // MARK: - Private Properties
    private let processingQueue = DispatchQueue(label: "com.achico.fileprocessing", qos: .userInitiated)
    private let cacheManager = CacheManager.shared
    
    // MARK: - Types
    enum CompressionError: LocalizedError {
        case unsupportedFormat
        case conversionFailed
        case compressionFailed
        case invalidInput
        
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "This file format is not supported"
            case .conversionFailed:
                return "Failed to convert the file"
            case .compressionFailed:
                return "Failed to compress the file"
            case .invalidInput:
                return "The input file is invalid or corrupted"
            }
        }
    }
    
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
    
    struct CompressionSettings {
        var quality: CGFloat = 0.7        // JPEG/HEIC quality (0.0-1.0)
        var pngCompressionLevel: Int = 6  // PNG compression (0-9)
        var preserveMetadata: Bool = false
        var maxDimension: CGFloat? = nil  // Downsample if larger
        var optimizeForWeb: Bool = true   // Additional optimizations for web use
    }
    
    // MARK: - Lifecycle
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    @MainActor
    func processFile(url: URL) async throws {
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
    
    func cleanup() {
        processingResult = nil
        cacheManager.cleanupOldFiles()
    }
    
    // MARK: - Private Methods - Main Processing
    private func processInBackground(url: URL) throws -> ProcessingResult {
        let originalSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        let tempURL = try cacheManager.createTemporaryURL(for: url.lastPathComponent)
        
        switch url.pathExtension.lowercased() {
        case "pdf":
            try processPDF(from: url, to: tempURL)
        case "jpg", "jpeg":
            try processJPEG(from: url, to: tempURL)
        case "png":
            try processPNG(from: url, to: tempURL)
        case "heic":
            try processHEIC(from: url, to: tempURL)
        case "tiff", "tif":
            try processTIFF(from: url, to: tempURL)
        case "gif":
            try processGIF(from: url, to: tempURL)
        case "bmp":
            try processBMP(from: url, to: tempURL)
        case "webp":
            try processWebP(from: url, to: tempURL)
        default:
            throw CompressionError.unsupportedFormat
        }
        
        let compressedSize = try FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64 ?? 0
        
        return ProcessingResult(
            originalSize: originalSize,
            compressedSize: compressedSize,
            compressedURL: tempURL,
            fileName: url.lastPathComponent
        )
    }
    
    // MARK: - Private Methods - Format-Specific Processing
    private func processPDF(from url: URL, to tempURL: URL) throws {
        guard let document = PDFDocument(url: url) else {
            throw CompressionError.conversionFailed
        }
        
        let newDocument = PDFDocument()
        let totalPages = document.pageCount
        
        for i in 0..<totalPages {
            autoreleasepool {
                if let page = document.page(at: i) {
                    if let compressedPage = try? compressPDFPage(page) {
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
        
        newDocument.write(to: tempURL)
    }
    
    private func processJPEG(from url: URL, to tempURL: URL) throws {
        guard let image = NSImage(contentsOf: url) else {
            throw CompressionError.conversionFailed
        }
        
        let settings = CompressionSettings(
            quality: 0.7,
            preserveMetadata: true,
            maxDimension: 2048,
            optimizeForWeb: true
        )
        
        guard let compressedData = compressImage(image, format: .jpeg, settings: settings) else {
            throw CompressionError.compressionFailed
        }
        
        try compressedData.write(to: tempURL)
    }
    
    private func processPNG(from url: URL, to tempURL: URL) throws {
        guard let image = NSImage(contentsOf: url) else {
            throw CompressionError.conversionFailed
        }
        
        let settings = CompressionSettings(
            pngCompressionLevel: 6,
            preserveMetadata: true,
            maxDimension: 2048,
            optimizeForWeb: true
        )
        
        guard let compressedData = compressImage(image, format: .png, settings: settings) else {
            throw CompressionError.compressionFailed
        }
        
        try compressedData.write(to: tempURL)
    }
    
    private func processHEIC(from url: URL, to tempURL: URL) throws {
        guard let image = NSImage(contentsOf: url) else {
            throw CompressionError.conversionFailed
        }
        
        let settings = CompressionSettings(
            quality: 0.8,
            preserveMetadata: true,
            maxDimension: 2048,
            optimizeForWeb: true
        )
        
        guard let compressedData = compressImage(image, format: .jpeg, settings: settings) else {
            throw CompressionError.compressionFailed
        }
        
        let jpegURL = tempURL.deletingPathExtension().appendingPathExtension("jpg")
        try compressedData.write(to: jpegURL)
    }
    
    private func processTIFF(from url: URL, to tempURL: URL) throws {
        guard let image = NSImage(contentsOf: url) else {
            throw CompressionError.conversionFailed
        }
        
        let settings = CompressionSettings(
            quality: 0.8,
            preserveMetadata: true,
            maxDimension: 2048,
            optimizeForWeb: true
        )
        
        guard let compressedData = compressImage(image, format: .jpeg, settings: settings) else {
            throw CompressionError.compressionFailed
        }
        
        try compressedData.write(to: tempURL)
    }
    
    private func processGIF(from url: URL, to tempURL: URL) throws {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw CompressionError.conversionFailed
        }
        
        let frameCount = CGImageSourceGetCount(imageSource)
        
        if frameCount > 1 {
            try compressAnimatedGIF(imageSource, frameCount: frameCount, to: tempURL)
        } else {
            guard let image = NSImage(contentsOf: url) else {
                throw CompressionError.conversionFailed
            }
            
            let settings = CompressionSettings(
                pngCompressionLevel: 6,
                preserveMetadata: true,
                maxDimension: 2048,
                optimizeForWeb: true
            )
            
            guard let compressedData = compressImage(image, format: .png, settings: settings) else {
                throw CompressionError.compressionFailed
            }
            
            let pngURL = tempURL.deletingPathExtension().appendingPathExtension("png")
            try compressedData.write(to: pngURL)
        }
    }
    
    private func processBMP(from url: URL, to tempURL: URL) throws {
        guard let image = NSImage(contentsOf: url) else {
            throw CompressionError.conversionFailed
        }
        
        let settings = CompressionSettings(
            pngCompressionLevel: 6,
            preserveMetadata: false,
            maxDimension: 2048,
            optimizeForWeb: true
        )
        
        guard let compressedData = compressImage(image, format: .png, settings: settings) else {
            throw CompressionError.compressionFailed
        }
        
        let pngURL = tempURL.deletingPathExtension().appendingPathExtension("png")
        try compressedData.write(to: pngURL)
    }
    
    private func processWebP(from url: URL, to tempURL: URL) throws {
        guard let image = NSImage(contentsOf: url) else {
            throw CompressionError.conversionFailed
        }
        
        let hasAlpha = imageHasAlpha(image)
        let format: NSBitmapImageRep.FileType = hasAlpha ? .png : .jpeg
        let settings = CompressionSettings(
            quality: 0.8,
            pngCompressionLevel: 6,
            preserveMetadata: true,
            maxDimension: 2048,
            optimizeForWeb: true
        )
        
        guard let compressedData = compressImage(image, format: format, settings: settings) else {
            throw CompressionError.compressionFailed
        }
        
        let newExt = hasAlpha ? "png" : "jpg"
        let newURL = tempURL.deletingPathExtension().appendingPathExtension(newExt)
        try compressedData.write(to: newURL)
    }
    
    // MARK: - Private Methods - Helper Functions
    private func compressPDFPage(_ page: PDFPage) throws -> PDFPage? {
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
    
    private func compressImage(_ image: NSImage, format: NSBitmapImageRep.FileType, settings: CompressionSettings) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let processedCGImage: CGImage
        if let maxDimension = settings.maxDimension {
            processedCGImage = resizeImage(cgImage, maxDimension: maxDimension) ?? cgImage
        } else {
            processedCGImage = cgImage
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: processedCGImage)
        
        var compressionProperties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        
        switch format {
        case .jpeg:
            compressionProperties[.compressionFactor] = settings.quality
        case .png:
            break
        default:
            break
        }
        
        return bitmapRep.representation(using: format, properties: compressionProperties)
    }
    
    private func imageHasAlpha(_ image: NSImage) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        
        let alphaInfo = cgImage.alphaInfo
        return alphaInfo != .none && alphaInfo != .noneSkipLast && alphaInfo != .noneSkipFirst
    }
    
    private func resizeImage(_ cgImage: CGImage, maxDimension: CGFloat) -> CGImage? {
        let currentWidth = CGFloat(cgImage.width)
        let currentHeight = CGFloat(cgImage.height)
        
        let scale = min(maxDimension / currentWidth, maxDimension / currentHeight)
        if scale >= 1.0 {
            return cgImage
        }
        
        let newWidth = currentWidth * scale
        let newHeight = currentHeight * scale
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        guard let colorSpace = cgImage.colorSpace else { return nil }
        guard let context = CGContext(
            data: nil,
            width: Int(newWidth),
            height: Int(newHeight),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else { return nil }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: newSize))
        
        return context.makeImage()
    }
    
    private func compressAnimatedGIF(_ imageSource: CGImageSource, frameCount: Int, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw CompressionError.compressionFailed
        }
        
        if let properties = CGImageSourceCopyProperties(imageSource, nil) {
            CGImageDestinationSetProperties(destination, properties)
                    }
                    
                    let options: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 1024
                    ]
                    
                    for i in 0..<frameCount {
                        autoreleasepool {
                            guard let frameProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) else {
                                return
                            }
                            
                            // Extract GIF-specific properties
                            let gifProperties = (frameProperties as Dictionary)[kCGImagePropertyGIFDictionary] as? Dictionary<CFString, Any>
                            
                            // Get delay time for the frame
                            let defaultDelay = 0.1
                            let delayTime: Double
                            if let delay = gifProperties?[kCGImagePropertyGIFDelayTime] as? Double {
                                delayTime = delay
                            } else {
                                delayTime = defaultDelay
                            }
                            
                            // Create optimized frame
                            guard let frameImage = CGImageSourceCreateImageAtIndex(imageSource, i, options as CFDictionary) else {
                                return
                            }
                            
                            // Prepare frame properties for destination
                            let destFrameProperties: [CFString: Any] = [
                                kCGImagePropertyGIFDictionary: [
                                    kCGImagePropertyGIFDelayTime: delayTime
                                ]
                            ]
                            
                            CGImageDestinationAddImage(destination, frameImage, destFrameProperties as CFDictionary)
                        }
                        
                        DispatchQueue.main.async {
                            self.progress = Double(i + 1) / Double(frameCount)
                        }
                    }
                    
                    if !CGImageDestinationFinalize(destination) {
                        throw CompressionError.compressionFailed
                    }
                }
                
                // MARK: - Metadata Handling
                private func extractMetadata(from imageSource: CGImageSource) -> [CFString: Any]? {
                    guard let properties = CGImageSourceCopyProperties(imageSource, nil) as? [CFString: Any] else {
                        return nil
                    }
                    
                    var metadata: [CFString: Any] = [:]
                    
                    // Extract relevant metadata while excluding unnecessary data
                    let keysToPreserve: [CFString] = [
                        kCGImagePropertyOrientation,
                        kCGImagePropertyDPIHeight,
                        kCGImagePropertyDPIWidth,
                        kCGImagePropertyPixelHeight,
                        kCGImagePropertyPixelWidth,
                        kCGImagePropertyProfileName
                    ]
                    
                    for key in keysToPreserve {
                        if let value = properties[key] {
                            metadata[key] = value
                        }
                    }
                    
                    return metadata
                }
                
                // MARK: - Quality and Optimization
                private func determineOptimalSettings(for image: NSImage, format: NSBitmapImageRep.FileType) -> CompressionSettings {
                    let size = image.size
                    let totalPixels = size.width * size.height
                    
                    // Base settings
                    var settings = CompressionSettings()
                    
                    // Adjust quality based on image size
                    if totalPixels > 4_000_000 { // 2000x2000 pixels
                        settings.maxDimension = 2048
                        settings.quality = 0.7
                    } else if totalPixels > 1_000_000 { // 1000x1000 pixels
                        settings.maxDimension = 1500
                        settings.quality = 0.8
                    } else {
                        settings.maxDimension = nil
                        settings.quality = 0.9
                    }
                    
                    // Format-specific adjustments
                    switch format {
                    case .jpeg:
                        // JPEG-specific optimizations
                        if totalPixels > 8_000_000 {
                            settings.quality = 0.6
                        }
                        settings.preserveMetadata = true
                        
                    case .png:
                        // PNG-specific optimizations
                        if imageHasAlpha(image) {
                            settings.pngCompressionLevel = 7
                        } else {
                            settings.pngCompressionLevel = 9
                        }
                        settings.preserveMetadata = true
                        
                    default:
                        settings.preserveMetadata = false
                    }
                    
                    return settings
                }
                
                // MARK: - Progress Tracking
                private func updateProgress(_ progress: Double) {
                    DispatchQueue.main.async {
                        self.progress = min(max(progress, 0), 1)
                    }
                }
            }

            // MARK: - Extensions
            extension FileProcessor {
                enum FileType {
                    case pdf
                    case jpeg
                    case png
                    case heic
                    case gif
                    case tiff
                    case bmp
                    case webp
                    case unknown
                    
                    init(url: URL) {
                        switch url.pathExtension.lowercased() {
                        case "pdf": self = .pdf
                        case "jpg", "jpeg": self = .jpeg
                        case "png": self = .png
                        case "heic": self = .heic
                        case "gif": self = .gif
                        case "tiff", "tif": self = .tiff
                        case "bmp": self = .bmp
                        case "webp": self = .webp
                        default: self = .unknown
                        }
                    }
                    
                    var canCompress: Bool {
                        self != .unknown
                    }
                    
                    var defaultOutputExtension: String {
                        switch self {
                        case .pdf: return "pdf"
                        case .jpeg: return "jpg"
                        case .png: return "png"
                        case .heic: return "jpg"  // Convert HEIC to JPEG
                        case .gif: return "gif"
                        case .tiff: return "jpg"  // Convert TIFF to JPEG
                        case .bmp: return "png"   // Convert BMP to PNG
                        case .webp: return "jpg"  // Convert WebP to JPEG
                        case .unknown: return ""
                        }
                    }
                }
            }
