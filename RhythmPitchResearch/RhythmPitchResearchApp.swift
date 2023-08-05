import SwiftUI

enum Tab {
    case home
    case spectogram
    case settings
}

@main
struct RhythmPitchResearchApp: App {
    let persistenceController = PersistenceController.shared
    @State private var selectedTab: Tab = .home
    @Environment(\.scenePhase) private var scenePhase
    let audioSpectrogram = AudioSpectrogram()
    
    var body: some Scene {
        WindowGroup {
//            TabView(selection: $selectedTab) {
//                ContentViewAnalyse()
//                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
//            }
//            .tabItem {
//                //Image(systemName: "house")
//                Text("Home")
//            }
//            .tag(Tab.home)
            
            TabView(selection: $selectedTab) {
                ContentViewSpectogram()
                    .environmentObject(audioSpectrogram)
                    .onChange(of: scenePhase) { phase in
                        if phase == .active {
                            Task(priority: .userInitiated) {
                                audioSpectrogram.startRunning()
                            }
                        }
                    }
            }
            .tabItem {
                //Image(systemName: "house")
                Text("Spectogram")
            }
            .tag(Tab.home)

        }
        
    }
}



