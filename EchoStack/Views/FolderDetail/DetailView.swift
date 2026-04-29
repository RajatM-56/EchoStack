import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import QuickLook


struct DetailView: View {
    
    @Environment(\.modelContext) private var context
    @Bindable var stack: SubjectStack
    @Query var allStacks: [SubjectStack]
    @Query(sort: \RecentFile.dateOpened, order: .reverse) var recentFiles: [RecentFile]
    var breadcrumbs: [String]
    
    // UI State
    @State private var showingFileImporter = false
    @State private var showingAddFileSheet = false
    @State private var isAddingLink = false
    @State private var showingStackMap = false
    @State private var showingFolderCreationSheet = false
    @State private var showingMoveSheet = false
    @State private var showingChat = false
    @State private var showingQuiz = false
    @State private var showingMindMap = false
    @State private var mindMapFileName: String? = nil
    
    // File Tracking
    @State private var customFileName = ""
    @State private var originalExtension = ""
    @State private var previewURL: URL?
    
    // Drag & Drop State
    @State private var draggedFileItem: FileItem?
    @State private var isTargeted = false
    
    // Edit/Folder Creation State
    @State private var editingItem: FileItem? = nil
    @State private var isEditing = false
    @State private var folderNameInput = ""
    @State private var selectedFolderColor: Color = .blue
    
    let paperBackground = Color(red: 0.98, green: 0.97, blue: 0.95)

    var body: some View {
        ZStack {
            paperBackground.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                headerView
                
                if stack.files.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                            ForEach(stack.files, id: \.self) { item in
                                gridItemView(for: item)
                            }
                        }
                        .padding()
                    }
                }
                
                dropZoneView
            }
        }
        .quickLookPreview($previewURL)
        // MARK: Sheets & Overlays
        .sheet(isPresented: $showingFolderCreationSheet) {
            folderCreationSheet
        }
        .sheet(isPresented: $showingMoveSheet) {
            MoveFileSheet(
                allStacks: allStacks,
                currentStackID: stack.id,
                fileName: fileNameFromItem(draggedItem: draggedFileItem)
            ) { targetID in
                if let item = draggedFileItem { moveFile(item, to: targetID) }
            }
            .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                saveFilePermanently(from: url)
            }
        }
        .sheet(isPresented: $showingAddFileSheet) {
            AddFilePopUp(stackColor: stack.color.swiftUIColor, isLink: isAddingLink, initialName: customFileName) { finalizedName, linkURL in
                let newName = isAddingLink ? "\(finalizedName)|\(linkURL)" : "\(finalizedName).\(originalExtension)"
                addFile(item: .file(id: UUID(), name: newName))
            }
            .presentationDetents([.height(350)])
        }
        .sheet(isPresented: $isEditing) {
            if let item = editingItem, case .file(let id, let fileName) = item {
                AddFilePopUp(
                    stackColor: stack.color.swiftUIColor,
                    isLink: fileName.contains("|"),
                    initialName: customFileName
                ) { newName, newURL in
                    updateItem(oldItem: item, oldID: id, newName: newName, newURL: newURL)
                }
                .presentationDetents([.height(350)])
            }
        }
        .sheet(isPresented: $showingStackMap) {
            stackMapSheet
        }
        .fullScreenCover(isPresented: $showingChat) {
            if #available(iOS 26.0, *) {
                StackChatView(stack: stack, allStacks: allStacks)
            } else {
                Text("Apple Intelligence requires iOS 26 or later.")
            }
        }
        .fullScreenCover(isPresented: $showingQuiz) {
            if #available(iOS 26.0, *) {
                QuizView(stack: stack, allStacks: allStacks)
            } else {
                Text("Apple Intelligence requires iOS 26 or later.")
            }
        }
        .fullScreenCover(isPresented: $showingMindMap) {
            if #available(iOS 26.0, *) {
                if let fileName = mindMapFileName {
                    AutoMindMapView(stack: stack, allStacks: allStacks, fileName: fileName)
                } else {
                    AutoMindMapView(stack: stack, allStacks: allStacks)
                }
            } else {
                Text("Apple Intelligence requires iOS 26 or later.")
            }
        }
    }
}


extension DetailView {
    
    private var fullPathString: String {
        let allNames = breadcrumbs + [stack.title]
        return allNames.joined(separator: " / ")
    }
    
    private var headerView: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading) {
                Text("My Stacks / \(fullPathString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Visualizer")
                    .font(.system(.largeTitle, design: .serif).bold())
            }
            Spacer()
            
            HStack(spacing: 16) {
                // AI Tools Menu
                Menu {
                    Button(action: { showingChat = true }) {
                        Label("Study Assistant", systemImage: "sparkles")
                    }
                    Button(action: { showingQuiz = true }) {
                        Label("Practice Quiz", systemImage: "questionmark.text.page.fill")
                    }
                    Button(action: { showingStackMap = true }) {
                        Label("Stack Map", systemImage: "waveform.and.magnifyingglass")
                    }
                    Button(action: { mindMapFileName = nil; showingMindMap = true }) {
                        Label("Mind Map", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                } label: {
                    Image(systemName: "cpu")
                        .font(.title3)
                        .padding(10)
                        .background(stack.color.swiftUIColor.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Menu {
                    Button(action: { showingFolderCreationSheet = true }) {
                        Label("Add Sub-Folder", systemImage: "folder.badge.plus")
                    }
                    Button(action: { isAddingLink = true; showingAddFileSheet = true }) {
                        Label("Add Link", systemImage: "link.badge.plus")
                    }
                    Button(action: { isAddingLink = false; showingFileImporter = true }) {
                        Label("Add File", systemImage: "doc.badge.plus")
                    }
                } label: {
                    ZStack {
                        Circle().fill(stack.color.swiftUIColor).frame(width: 40, height: 40)
                        Image(systemName: "plus").foregroundColor(.white).font(.system(size: 18, weight: .bold))
                    }
                }
            }
        }
        .foregroundColor(stack.color.swiftUIColor)
        .padding(.horizontal)
    }

    private var dropZoneView: some View {
        VStack(spacing: 12) {
            Image(systemName: isTargeted ? "tray.full.fill" : "square.and.arrow.down.on.square").font(.title)
            Text(isTargeted ? "Release to Move" : "Drag item here to re-organize").font(.caption2.bold())
        }
        .foregroundColor(stack.color.swiftUIColor)
        .frame(maxWidth: .infinity).frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .stroke(stack.color.swiftUIColor.opacity(isTargeted ? 0.6 : 0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
        )
        .padding()
        .onDrop(of: [.plainText], isTargeted: $isTargeted) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showingMoveSheet = true }
            return true
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Image(systemName: "folder.badge.plus").font(.system(size: 60)).opacity(0.1)
            Text("Stack is empty").font(.headline).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .foregroundColor(stack.color.swiftUIColor)
    }
    
    private var folderCreationSheet: some View {
        VStack(spacing: 25) {
            Text("New Sub-Folder").font(.headline).padding(.top)
            
            TextField("Enter folder name", text: $folderNameInput)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose Cover Color").font(.subheadline).foregroundColor(.secondary)
                HStack(spacing: 15) {
                    ForEach([Color.red, .blue, .green, .orange, .purple, .teal, .pink], id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 35, height: 35)
                            .overlay(Circle().stroke(Color.primary, lineWidth: selectedFolderColor == color ? 2 : 0))
                            .onTapGesture { selectedFolderColor = color }
                    }
                }
            }
            .padding(.horizontal)
            
            HStack {
                Button("Cancel") { showingFolderCreationSheet = false }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Create") {
                    createSubFolder(named: folderNameInput, color: selectedFolderColor)
                    showingFolderCreationSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(folderNameInput.isEmpty)
            }
            .padding(.horizontal)
            Spacer()
        }
        .padding(.top, 20)
        .presentationDetents([.height(320)])
    }
    
    private var stackMapSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.98, green: 0.98, blue: 0.98).ignoresSafeArea()
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    StackMapView(node: buildTree(for: stack))
                        .padding(40)
                }
            }
            .navigationTitle("Folder Structure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingStackMap = false }
                }
            }
        }
    }

    @ViewBuilder
    private func gridItemView(for item: FileItem) -> some View {
        switch item {
        case .file(_, let fileName):
            FileNode(fileName: fileName, color: stack.color.swiftUIColor, isFolder: false)
                .onTapGesture { openFile(fileName) }
                .onDrag {
                    self.draggedFileItem = item
                    return NSItemProvider(object: fileName as NSString)
                }
                .onDrop(of: [.plainText], delegate: FileDropDelegate(item: item, stack: stack, draggedItem: $draggedFileItem))
                .contextMenu {
                    editButton(for: item, fileName: fileName)
                    if !fileName.contains("|") {
                        Button {
                            mindMapFileName = fileName
                            showingMindMap = true
                        } label: {
                            Label("Mind Map", systemImage: "point.3.connected.trianglepath.dotted")
                        }
                    }
                    deleteButton(for: item)
                }
                
        case .folder(let subStackID):
                    if let subStack = allStacks.first(where: { $0.id == subStackID }) {
                        NavigationLink(destination: DetailView(
                            stack: subStack,
                            breadcrumbs: breadcrumbs + [stack.title]
                        )) {
                            VStack {
                                ZStack(alignment: .bottomLeading) {
                                    BookFolderView(
                                        title: subStack.title,
                                        itemCount: subStack.files.count,
                                        color: subStack.color.swiftUIColor
                                    )
                                }
                                .scaleEffect(0.85)
                            }
                            .frame(width: 110, height: 150)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            deleteButton(for: item)
                        }
                    }
        }
    }

    @ViewBuilder
    private func editButton(for item: FileItem, fileName: String) -> some View {
        Button {
            self.editingItem = item
            if fileName.contains("|") {
                self.customFileName = fileName.components(separatedBy: "|").first ?? ""
            } else {
                self.customFileName = (fileName as NSString).deletingPathExtension
            }
            self.isEditing = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }
    }
    
    @ViewBuilder
    private func deleteButton(for item: FileItem) -> some View {
        Button(role: .destructive) { deleteItem(item) } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

extension DetailView {
    
    func createSubFolder(named name: String, color: Color) {
            guard !name.isEmpty else { return }
            
            // 1. Create the new folder object
            let newSubFolder = SubjectStack(
                id: UUID(),
                title: name,
                itemCount: 0,
                color: color,
                files: [],
                isSubFolder: true
            )
            
            withAnimation(.spring()) {
                context.insert(newSubFolder)
                
                stack.files.append(.folder(id: newSubFolder.id))
                stack.itemCount = stack.files.count
                
                folderNameInput = ""
            }
        }
    
    func openFile(_ fileName: String) {
            if fileName.contains("|") {
                let components = fileName.components(separatedBy: "|")
                if let rawURLString = components.last?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let url = URL(string: rawURLString) {
                    
                    updateRecents(for: fileName)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        UIApplication.shared.open(url)
                    }
                }
                return
            }
            
            let docsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = docsDirectory.appendingPathComponent(fileName)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                self.previewURL = fileURL
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                
                updateRecents(for: fileName)
            }
        }

    private func updateRecents(for fileName: String) {
        Task { @MainActor in
            if let existing = recentFiles.first(where: { $0.fileName == fileName }) {
                context.delete(existing)
            }
            
            let newRecent = RecentFile(
                id: UUID(),
                fileName: fileName,
                stackColor: stack.color,
                dateOpened: Date()
            )
            context.insert(newRecent)
        }
    }
    
    func saveFilePermanently(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let fileManager = FileManager.default
        let docsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        self.originalExtension = url.pathExtension
        self.customFileName = url.deletingPathExtension().lastPathComponent
        let destination = docsDirectory.appendingPathComponent(url.lastPathComponent)
        
        do {
            if fileManager.fileExists(atPath: destination.path) { try? fileManager.removeItem(at: destination) }
            try fileManager.copyItem(at: url, to: destination)
            self.showingAddFileSheet = true
        } catch {
            print("Import Error: \(error.localizedDescription)")
        }
    }

    func moveFile(_ item: FileItem, to destID: UUID) {
        if case .folder(let movingStackID) = item {
            if isDestinationInside(movingStackID: movingStackID, targetFolderID: destID) {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                draggedFileItem = nil
                showingMoveSheet = false
                return
            }
        }

        withAnimation(.spring()) {
            stack.files.removeAll { $0 == item }
            stack.itemCount = stack.files.count
            
            if let index = allStacks.firstIndex(where: { $0.id == destID }) {
                if !allStacks[index].files.contains(item) {
                    allStacks[index].files.append(item)
                    allStacks[index].itemCount = allStacks[index].files.count
                }
            }
            
            draggedFileItem = nil
            showingMoveSheet = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func isDestinationInside(movingStackID: UUID, targetFolderID: UUID) -> Bool {
        if movingStackID == targetFolderID { return true }
        guard let movingStack = allStacks.first(where: { $0.id == movingStackID }) else { return false }
        
        for item in movingStack.files {
            if case .folder(let subRefID) = item {
                if subRefID == targetFolderID { return true }
                if isDestinationInside(movingStackID: subRefID, targetFolderID: targetFolderID) {
                    return true
                }
            }
        }
        return false
    }
    
    func addFile(item: FileItem) {
        withAnimation(.spring()) {
            if !stack.files.contains(item) {
                stack.files.append(item)
                stack.itemCount = stack.files.count
            }
        }
    }

    func updateItem(oldItem: FileItem, oldID: UUID, newName: String, newURL: String) {
        if let index = stack.files.firstIndex(of: oldItem) {
            withAnimation {
                let finalName = newURL.isEmpty ? "\(newName).\(originalExtension)" : "\(newName)|\(newURL)"
                stack.files[index] = .file(id: oldID, name: finalName)
            }
        }
        editingItem = nil
    }

    func deleteItem(_ item: FileItem) {
        withAnimation(.spring()) {
            stack.files.removeAll { $0 == item }
            stack.itemCount = stack.files.count
            
            switch item {
            case .file(_, let fileName):
                let docsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let path = docsDirectory.appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: path)
                
            case .folder(_):
                break
            }
        }
    }
    
    private func fileNameFromItem(draggedItem: FileItem?) -> String {
        guard let item = draggedItem else { return "" }
        switch item {
        case .file(_, let name): return name
        case .folder(_): return "Folder"
        }
    }
    

    private func getFolderSize(for folder: SubjectStack) -> String {
        let sizeInBytes = calculateStackSizeInBytes(folder)
        if sizeInBytes == 0 { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeInBytes)
    }

    private func calculateStackSizeInBytes(_ folder: SubjectStack, visited: Set<UUID> = [], depth: Int = 0) -> Int64 {
        if visited.contains(folder.id) || depth > 10 { return 0 }
        
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var totalSize: Int64 = 0
        var newVisited = visited
        newVisited.insert(folder.id)

        for item in folder.files {
            switch item {
            case .file(_, let fileName):
                if !fileName.contains("|") {
                    let fileURL = docsURL.appendingPathComponent(fileName)
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                       let size = attributes[.size] as? Int64 {
                        totalSize += size
                    }
                }
            case .folder(let subFolderRefID):
                if let actualSubFolder = allStacks.first(where: { $0.id == subFolderRefID }) {
                    totalSize += calculateStackSizeInBytes(actualSubFolder, visited: newVisited, depth: depth + 1)
                }
            }
        }
        return totalSize
    }
    

    private func buildTree(for rootStack: SubjectStack, currentDepth: Int = 0) -> StackTreeNode {
        if currentDepth > 5 {
            return StackTreeNode(id: UUID(), name: "Max Depth reached", color: .gray, children: [], isFile: false)
        }
        
        var childrenNodes: [StackTreeNode] = []
        
        for item in rootStack.files {
            switch item {
            case .folder(let subFolderRefID):
                if let fullSubStack = allStacks.first(where: { $0.id == subFolderRefID }) {
                    childrenNodes.append(buildTree(for: fullSubStack, currentDepth: currentDepth + 1))
                }
            case .file(_, let name):
                let fileName = name.contains("|") ? (name.components(separatedBy: "|").first ?? name) : name
                childrenNodes.append(StackTreeNode(
                    id: UUID(),
                    name: fileName,
                    color: rootStack.color.swiftUIColor.opacity(0.7),
                    children: [],
                    isFile: true
                ))
            }
        }
        
        return StackTreeNode(
            id: rootStack.id,
            name: rootStack.title,
            color: rootStack.color.swiftUIColor,
            children: childrenNodes,
            isFile: false
        )
    }
}
