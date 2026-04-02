//
//  Models.swift
//  EchoStack
//
//  Created by GEU on 02/04/26.
//

import SwiftUI
import SwiftData


@Model
final class SubjectStack: Identifiable, Hashable {
    var id: UUID
    var title: String
    var itemCount: Int
    var color: CodableColor
    var files: [FileItem]
    var isSubFolder: Bool
    
    init(id: UUID = UUID(), title: String, itemCount: Int, color: Color, files: [FileItem] = [], isSubFolder: Bool = false) {
        self.id = id
        self.title = title
        self.itemCount = itemCount
        self.color = CodableColor(color)
        self.files = files
        self.isSubFolder = isSubFolder
    }
}

enum FileItem: Identifiable, Hashable, Codable {
    case file(id: UUID, name: String)
    case folder(id: UUID)
    
    var id: UUID {
        switch self {
        case .file(let fileID, _):
            return fileID
        case .folder(let folderID):
            return folderID
        }
    }
}


@Model
final class RecentFile: Identifiable, Equatable {
    var id: UUID
    var fileName: String
    var stackColor: CodableColor
    var dateOpened: Date
    
    init(id: UUID = UUID(), fileName: String, stackColor: CodableColor, dateOpened: Date) {
        self.id = id
        self.fileName = fileName
        self.stackColor = stackColor
        self.dateOpened = dateOpened
    }
}

struct StackTreeNode: Identifiable {
    let id: UUID
    let name: String
    let color: Color
    var children: [StackTreeNode]
    var isFile: Bool
}


struct CodableColor: Codable, Hashable {
    var red, green, blue, opacity: Double

    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}
