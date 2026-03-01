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
                    // Delayed fallback in case store wasn't ready on first onAppear (cold launch)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        generateDueRecurringTransactions()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .persistentStoreDidLoad)) { _ in
                    generateDueRecurringTransactions()
                }
                .task {
                    await currencyViewModel.fetchRatesFromAPI()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                generateDueRecurringTransactions()
                Task { await currencyViewModel.fetchRatesFromAPI() }
            }
        }
    }
    
    private func generateDueRecurringTransactions() {
        let context = persistence.container.viewContext
        let recurringEngine = RecurringEngine(context: context)
        recurringEngine.generateDueTransactions()
    }
}

