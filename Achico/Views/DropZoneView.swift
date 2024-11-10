import SwiftUI

struct DropZoneView: View {
    @Binding var isDragging: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: "doc.circle")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                
                Text("Drop your file here")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isDragging ? Color.accentColor : Color.secondary.opacity(0.2),
                                style: StrokeStyle(lineWidth: 1))
                    .background(Color.clear)
            )
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}
