import SwiftUI

struct ResultView: View {
    let result: PDFProcessor.ProcessingResult
    let onDownload: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(result.savedPercentage > 0 ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(result.savedPercentage > 0 ? "Compressed successfully" : "Compression not needed")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                (result.savedPercentage > 0 ? Color.green : Color.orange)
                    .opacity(0.1)
            )
            .cornerRadius(16)
            
            if result.savedPercentage > 0 {
                Text("\(result.savedPercentage)% smaller")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Text("File is already optimized")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                Button("Download", action: onDownload)
                    .buttonStyle(GlassButtonStyle())
                
                Button("Compress another", action: onReset)
                    .buttonStyle(GlassButtonStyle())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: 250)
    }
}
