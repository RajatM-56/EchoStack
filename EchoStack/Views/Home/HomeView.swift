import SwiftUI
import SwiftData
import QuickLook


@available(iOS 17.0, *)
struct HomeView: View {
    @Environment(\.modelContext) private var context
    

    @Query(filter: #Predicate<SubjectStack> { $0.isSubFolder == false }) var rootStacks: [SubjectStack]
    @Query var allStacks: [SubjectStack]
    @Query(sort: \RecentFile.dateOpened, order: .reverse) var recentFiles: [RecentFile]
    
    // UI State
    @State private var showingAddFolderSheet = false
    @State private var showingVoiceSearchSheet = false
    @State private var showingRenameAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var previewURL: URL?
    
    // Action State
    @State private var stackToRename: SubjectStack?
    @State private var newStackName: String = ""
    @State private var selectedStackFromVoice: SubjectStack?
    @State private var stackToDelete: SubjectStack?
    
    let paperBackground = Color(red: 0.98, green: 0.97, blue: 0.95)
    let inkColor = Color(red: 0.1, green: 0.1, blue: 0.15)
    
    var body: some View {
        NavigationStack {
            ZStack {
                paperBackground.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    continueCardSection
                    stacksTitleSection
                    stacksGridSection
                }
                
                bottomButtonsOverlay
            }
            .navigationTitle("") // Keeps the header clean
            .navigationBarHidden(true)
            // MARK: Navigation Destinations
            .navigationDestination(for: SubjectStack.self) { stack in
                DetailView(stack: stack, breadcrumbs: [])
            }
            .navigationDestination(item: $selectedStackFromVoice) { stack in
                DetailView(stack: stack, breadcrumbs: [])
            }
            // MARK: Sheet Presentation (Moved outside ZStack for stability)
            .sheet(isPresented: $showingAddFolderSheet) {
                AddFolderView()
            }
            .sheet(isPresented: $showingVoiceSearchSheet) {
                            VoiceSearchView(allStacks: allStacks) { found in
                                // Add a slight delay so the sheet physically disappears
                                // before the NavigationStack tries to slide the new view in.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    self.selectedStackFromVoice = found
                                }
                            }
                            .presentationDetents([.medium, .large])
                        }
            // MARK: Alerts & Dialogs
            .alert("Rename Stack", isPresented: $showingRenameAlert) {
                TextField("Enter new name", text: $newStackName)
                Button("Cancel", role: .cancel) { stackToRename = nil }
                Button("Save") { performRename() }
            } message: {
                Text("Enter a new title for this subject.")
            }
            .confirmationDialog(
                "Delete \(stackToDelete?.title ?? "Stack")?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let stack = stackToDelete { deleteStack(stack) }
                }
                Button("Cancel", role: .cancel) { stackToDelete = nil }
            } message: {
                Text("This will permanently delete this stack and all its hidden sub-folders.")
            }
            .quickLookPreview($previewURL)
        }
    }
}


@available(iOS 17.0, *)
extension HomeView {
    private var headerSection: some View {
        Text("Library")
            .font(.largeTitle)
            .fontWeight(.bold)
            .fontDesign(.serif)
            .foregroundColor(inkColor)
            .padding(.horizontal)
            .padding(.top, 15)
    }
    
    private var continueCardSection: some View {
        ContinueCard(
            fileName: recentFiles.first?.fileName ?? "No recent files",
            inkColor: inkColor
        )
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 30)
        .onTapGesture {
            if let mostRecent = recentFiles.first { openRecentFile(mostRecent.fileName) }
        }
    }
    
    private var stacksTitleSection: some View {
        Text("My Stacks")
            .font(.system(.title3, design: .serif).bold())
            .foregroundColor(inkColor)
            .padding(.horizontal)
            .padding(.bottom, 15)
    }
    
    private var stacksGridSection: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 20)], spacing: 25) {
                ForEach(rootStacks) { stack in
                    stackItem(stack)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 120)
        }
    }
    
    private func stackItem(_ stack: SubjectStack) -> some View {
        NavigationLink(value: stack) {
            ZStack(alignment: .bottomLeading) {
                BookFolderView(
                    title: stack.title,
                    itemCount: stack.itemCount,
                    color: stack.color.swiftUIColor
                )
                
                // Storage Badge
                VStack(alignment: .leading, spacing: 2) {
                    Text(getFolderSize(for: stack))
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(stack.color.swiftUIColor.opacity(0.8))
                        .cornerRadius(3)
                }
                .padding(.leading, 12)
                .padding(.bottom, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button {
                stackToRename = stack
                newStackName = stack.title
                showingRenameAlert = true
            } label: { Label("Rename", systemImage: "pencil") }
            
            Button(role: .destructive) {
                stackToDelete = stack
                showingDeleteConfirmation = true
            } label: { Label("Delete", systemImage: "trash") }
        }
    }
    
    private var bottomButtonsOverlay: some View {
            VStack {
                Spacer()
                ZStack {
                    // The Voice Search Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        
                        DispatchQueue.main.async {
                            showingVoiceSearchSheet = true
                        }
                    }) {
                        SpeakButtonUI()
                    }
                    .buttonStyle(.plain)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showingAddFolderSheet = true
                        }) {
                            FloatingAddButton()
                                .contentShape(Rectangle()) 
                        }
                        .padding(.trailing, 25)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 15)
            }
            .allowsHitTesting(true)
        }
}

@available(iOS 17.0, *)
extension HomeView {
    private func performRename() {
        if let stack = stackToRename {
            stack.title = newStackName
        }
        stackToRename = nil
    }
    
    private func openRecentFile(_ fileName: String) {
        let docsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docsDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: url.path) { self.previewURL = url }
    }
    
    private func deleteStack(_ stack: SubjectStack) {
        withAnimation {
            let subFolderIDs = stack.files.compactMap { if case .folder(let id) = $0 { return id } else { return nil } }
            for subID in subFolderIDs {
                if let subStack = allStacks.first(where: { $0.id == subID }) { context.delete(subStack) }
            }
            
            for item in stack.files {
                if case .file(_, let fileName) = item {
                    let docsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let path = docsDirectory.appendingPathComponent(fileName)
                    try? FileManager.default.removeItem(at: path)
                }
            }
            context.delete(stack)
        }
    }
    
    private func getFolderSize(for stack: SubjectStack) -> String {
        let sizeInBytes = calculateStackSizeInBytes(stack)
        return sizeInBytes == 0 ? "" : ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }

    private func calculateStackSizeInBytes(_ stack: SubjectStack) -> Int64 {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var totalSize: Int64 = 0

        for item in stack.files {
            switch item {
            case .file(_, let fileName):
                if !fileName.contains("|") {
                    let fileURL = docsURL.appendingPathComponent(fileName)
                    if let attr = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                       let size = attr[.size] as? Int64 { totalSize += size }
                }
            case .folder(let subFolderID):
                if let actualSubFolder = allStacks.first(where: { $0.id == subFolderID }) {
                    totalSize += calculateStackSizeInBytes(actualSubFolder)
                }
            }
        }
        return totalSize
    }
}
