import SwiftUI
import CoreData

struct LogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var selectedCategory: MoneyCategory?
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var selectedMonth: MonthKey?
    @State private var showAddTransaction = false
    @State private var showQuickAdd = false
    @State private var transactionToEdit: CDTransaction?
    @State private var deletedTransaction: CDTransaction?
    @State private var showUndoToast = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: false)]
    )
    private var allTransactions: FetchedResults<CDTransaction>
    
    private var availableMonths: [MonthKey] {
        let months = Set(allTransactions.map { $0.date.monthKey() })
        return Array(months).sorted(by: >)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filters
                    VStack(spacing: 12) {
                        CyberSearchBar(text: $searchText)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                CyberFilterButton(
                                    title: selectedMonth?.title ?? "Month",
                                    isActive: selectedMonth != nil
                                ) {
                                    // Month picker handled by menu
                                }
                                .overlay {
                                    Menu {
                                        Button("All Months") {
                                            selectedMonth = nil
                                        }
                                        ForEach(availableMonths, id: \.self) { month in
                                            Button(month.title) {
                                                selectedMonth = month
                                            }
                                        }
                                    } label: {
                                        Color.clear
                                    }
                                }
                                
                                CyberFilterButton(
                                    title: selectedCategory?.rawValue ?? "Category",
                                    isActive: selectedCategory != nil
                                ) { }
                                .overlay {
                                    Menu {
                                        Button("All Categories") {
                                            selectedCategory = nil
                                        }
                                        ForEach(MoneyCategory.allCases) { category in
                                            Button(category.rawValue) {
                                                selectedCategory = category
                                            }
                                        }
                                    } label: {
                                        Color.clear
                                    }
                                }
                                
                                CyberFilterButton(
                                    title: selectedPaymentMethod?.rawValue ?? "Payment",
                                    isActive: selectedPaymentMethod != nil
                                ) { }
                                .overlay {
                                    Menu {
                                        Button("All Methods") {
                                            selectedPaymentMethod = nil
                                        }
                                        ForEach(PaymentMethod.allCases) { method in
                                            Button(method.rawValue) {
                                                selectedPaymentMethod = method
                                            }
                                        }
                                    } label: {
                                        Color.clear
                                    }
                                }
                                
                                if selectedCategory != nil || selectedPaymentMethod != nil || selectedMonth != nil || !searchText.isEmpty {
                                    Button("Clear") {
                                        selectedCategory = nil
                                        selectedPaymentMethod = nil
                                        selectedMonth = nil
                                        searchText = ""
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.neonPink)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color.cyberDarkGray)
                    
                    TransactionQueryList(
                        searchText: searchText,
                        category: selectedCategory,
                        paymentMethod: selectedPaymentMethod,
                        month: selectedMonth,
                        onTap: { transaction in
                            transactionToEdit = transaction
                        },
                        onDelete: { transaction in
                            deletedTransaction = transaction
                            viewContext.delete(transaction)
                            PersistenceController.shared.save(viewContext)
                            showUndoToast = true
                        }
                    )
                }
            }
            .cyberNavTitle("Transaction Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showQuickAdd = true
                        } label: {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.neonGreen)
                        }
                        Button {
                            showAddTransaction = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.neonGreen)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddEditTransactionView()
            }
            .sheet(isPresented: $showQuickAdd) {
                PresetsQuickAddSheet()
            }
            .sheet(item: $transactionToEdit) { transaction in
                AddEditTransactionView(transaction: transaction)
            }
            .toast(isPresented: $showUndoToast) {
                CyberToast(
                    text: "Transaction deleted",
                    actionTitle: "Undo",
                    action: {
                        if let deleted = deletedTransaction {
                            viewContext.insert(deleted)
                            PersistenceController.shared.save(viewContext)
                            deletedTransaction = nil
                        }
                        showUndoToast = false
                    }
                )
            }
        }
    }
}

// MARK: - Cyberpunk Search Bar
struct CyberSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.neonGreen.opacity(0.7))
            
            TextField("Search merchant or notes", text: $text)
                .foregroundColor(.white)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(12)
        .background(Color.cyberGray)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.neonGreen.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Cyberpunk Filter Button
struct CyberFilterButton: View {
    let title: String
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(isActive ? .cyberBlack : .neonGreen)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? Color.neonGreen : Color.cyberGray)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.neonGreen.opacity(isActive ? 0 : 0.5), lineWidth: 1)
            )
        }
    }
}

// MARK: - Cyberpunk Toast
struct CyberToast: View {
    let text: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 16) {
            Text(text)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.neonGreen)
                }
            }
        }
        .padding(16)
        .background(Color.cyberDarkGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.neonGreen.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .neonGreenGlow, radius: 10)
        .padding()
    }
}
