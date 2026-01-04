import SwiftUI
import CoreData

@main
struct MoneyTrackApp: App {
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}

