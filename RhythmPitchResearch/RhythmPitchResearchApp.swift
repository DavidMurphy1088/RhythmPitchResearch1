//
//  RhythmPitchResearchApp.swift
//  RhythmPitchResearch
//
//  Created by David Murphy on 6/21/23.
//

import SwiftUI

@main
struct RhythmPitchResearchApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
