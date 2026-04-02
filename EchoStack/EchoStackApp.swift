//
//  EchoStackApp.swift
//  EchoStack
//
//  Created by GEU on 02/04/26.
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [SubjectStack.self, RecentFile.self])
    }
}
