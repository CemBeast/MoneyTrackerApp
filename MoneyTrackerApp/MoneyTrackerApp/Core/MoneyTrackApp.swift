import SwiftUI
import CoreData

@main
struct MoneyTrackApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var currencyViewModel = CurrencyViewModel()
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .environmentObject(currencyViewModel)
                .onAppear {
                    generateDueRecurringTransactions()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                generateDueRecurringTransactions()
            }
        }
    }
    
    private func generateDueRecurringTransactions() {
        let context = persistence.container.viewContext
        let recurringEngine = RecurringEngine(context: context)
        recurringEngine.generateDueTransactions()
    }
}

