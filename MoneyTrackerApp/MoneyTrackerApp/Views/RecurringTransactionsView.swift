//
//  RecurringTransactionsView.swift
//  MoneyTrackerApp
//
//  Displays all transactions marked as recurring (templates only, not generated instances).
//

import SwiftUI
import CoreData

struct RecurringTransactionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var currencyViewModel: CurrencyViewModel

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: false)],
        predicate: NSPredicate(format: "isRecurring == YES AND generatedFromRecurringId == nil")
    )
    private var recurringTransactions: FetchedResults<CDTransaction>

    @State private var transactionToRemove: CDTransaction?

    var body: some View {
        ZStack {
            Color.cyberBlack.ignoresSafeArea()

            if recurringTransactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "repeat.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.neonGreen.opacity(0.3))

                    Text("No recurring transactions")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.5))

                    Text("Mark a transaction as recurring when adding or editing it")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(recurringTransactions) { transaction in
                            NavigationLink(destination: AddEditTransactionView(transaction: transaction)) {
                                CyberTransactionRow(
                                    transaction: transaction,
                                    currencyViewModel: currencyViewModel
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    transactionToRemove = transaction
                                } label: {
                                    Label("Remove Recurring", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .cyberNavTitle("Recurring")
        .confirmationDialog(
            "Remove Recurring?",
            isPresented: Binding(
                get: { transactionToRemove != nil },
                set: { if !$0 { transactionToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Recurring", role: .destructive) {
                if let transaction = transactionToRemove {
                    stopRecurring(transaction)
                }
                transactionToRemove = nil
            }
            Button("Cancel", role: .cancel) {
                transactionToRemove = nil
            }
        } message: {
            Text("No new transactions will be generated. Past logged transactions are kept.")
        }
    }

    /// Stops future generation without deleting anything. The template is itself the first logged
    /// occurrence, so it stays as a regular transaction; generated instances keep their link via
    /// generatedFromRecurringId. recurringGroupId is kept so re-enabling won't duplicate past months.
    private func stopRecurring(_ transaction: CDTransaction) {
        transaction.isRecurring = false
        transaction.recurringIntervalRaw = nil
        PersistenceController.shared.save(viewContext)
    }
}
