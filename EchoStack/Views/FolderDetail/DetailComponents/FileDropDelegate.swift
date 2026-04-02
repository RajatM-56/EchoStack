import SwiftUI

struct FileDropDelegate: DropDelegate {
    let item: FileItem
    
    var stack: SubjectStack
    
    @Binding var draggedItem: FileItem?
    
    func performDrop(info: DropInfo) -> Bool { draggedItem = nil; return true }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem, draggedItem != item,
              let from = stack.files.firstIndex(of: draggedItem),
              let to = stack.files.firstIndex(of: item) else { return }
        
        if stack.files[to] != draggedItem {
            withAnimation(.default) {
                stack.files.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }
}
