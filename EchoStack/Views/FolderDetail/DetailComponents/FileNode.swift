import SwiftUI

struct FileNode: View {
    let fileName: String
    let color: Color
    var isFolder: Bool = false
    
    var displayTitle: String {
        if !isFolder && fileName.contains("|") {
            return fileName.components(separatedBy: "|").first ?? fileName
        }
        return fileName
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            
            VStack(spacing: 10) {
                Image(systemName: isFolder ? "folder.fill" : (fileName.contains("|") ? "link" : iconForFile(fileName)))
                    .font(.system(size: 30))
                    .foregroundColor(color)
                
                Text(displayTitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .lineLimit(2)
            }
        }
        .frame(height: 120)
    }
    
    func iconForFile(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains(".pdf") { return "doc.append.fill" }
        if n.contains(".docx") || n.contains(".doc") { return "doc.text.fill" }
        if n.contains(".png") || n.contains(".jpg") || n.contains(".jpeg") { return "photo.fill" }
        if n.contains(".mp4") || n.contains(".mov") { return "video.fill" }
        return "doc.fill"
    }
}
