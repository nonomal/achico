import SwiftUI
import UniformTypeIdentifiers
import QuickLook

struct PDFDropDelegate: DropDelegate {
    @Binding var isDragging: Bool
    let handlePDF: (URL) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [UTType.pdf])
    }
    
    func dropEntered(info: DropInfo) {
        isDragging = true
    }
    
    func dropExited(info: DropInfo) {
        isDragging = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isDragging = false
        guard let itemProvider = info.itemProviders(for: [UTType.pdf]).first else { return false }
        
        itemProvider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { (urlData, error) in
            if let urlData = urlData as? Data,
               let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                DispatchQueue.main.async {
                    handlePDF(url)
                }
            }
        }
        return true
    }
}
