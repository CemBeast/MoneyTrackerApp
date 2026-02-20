import SwiftUI
import CoreData

struct TransactionQueryList: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var currencyViewModel: CurrencyViewModel
    @FetchRequest private var transactions: FetchedResults<CDTransaction>
    
    let onTap: (CDTransaction) -> Void
    let onDelete: ((CDTransaction) -> Void)?
    
    init(
        searchText: String = "",
        category: MoneyCategory? = nil,
        paymentMethod: PaymentMethod? = nil,
        month: MonthKey? = nil,
        onTap: @escaping (CDTransaction) -> Void,
        onDelete: ((CDTransaction) -> Void)? = nil
    ) {
        self.onTap = onTap
        self.onDelete = onDelete
        
        var predicates: [NSPredicate] = []
        
        // Search text (merchant + notes)
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(format: "merchant CONTAINS[cd] %@ OR notes CONTAINS[cd] %@", searchText, searchText)
            predicates.append(searchPredicate)
        }
        
        // Category filter
        if let category = category {
            predicates.append(NSPredicate(format: "categoryRaw == %@", category.rawValue))
        }
        
        // Payment method filter
        if let paymentMethod = paymentMethod {
            predicates.append(NSPredicate(format: "paymentMethodRaw == %@", paymentMethod.rawValue))
        }
        
        // Month filter
        if let month = month {
            let startDate = month.startDate
            let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
            predicates.append(NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate))
        }
        
        let finalPredicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = finalPredicate
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: false)]
        
        _transactions = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(transactions) { transaction in
                    CyberTransactionRow(transaction: transaction, currencyViewModel: currencyViewModel)
                        .id("\(transaction.id)-\(transaction.amount)-\(transaction.date.timeIntervalSince1970)-\(transaction.paymentMethodRaw ?? "")-\(transaction.categoryRaw)-\(transaction.notes ?? "")")
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTap(transaction)
                        }
                        .contextMenu {
                            Button {
                                onTap(transaction)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            if let onDelete = onDelete {
                                Divider()
                                Button(role: .destructive) {
                                    onDelete(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
                
                if transactions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.neonGreen.opacity(0.3))
                        
                        Text("No transactions")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("Tap + to add your first transaction")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color.cyberBlack)
    }
}

struct CyberTransactionRow: View {
    let transaction: CDTransaction
    @ObservedObject var currencyViewModel: CurrencyViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: categoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant ?? "No merchant")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let notes = transaction.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    CyberTag(text: transaction.category.rawValue, color: categoryColor)
                    
                    Text(transaction.paymentMethod.rawValue)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(currencyViewModel.format(amountInBase: transaction.amount))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.neonGreen)
                
                Text(transaction.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(Color.cyberDarkGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.neonGreen.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var categoryColor: Color {
        transaction.category.color
    }
    
    private var categoryIcon: String {
        switch transaction.category {
        case .housing: return "house.fill"
        case .fixedBills: return "building.2.fill"
        case .food: return "fork.knife"
        case .transportation: return "car.fill"
        case .healthcare: return "cross.case.fill"
        case .funLifestyle: return "gamecontroller.fill"
        case .shopping: return "bag.fill"
        case .subscriptions: return "repeat"
        case .savings: return "banknote.fill"
        case .investing: return "chart.line.uptrend.xyaxis"
        case .travel: return "airplane"
        case .gifts: return "gift.fill"
        case .misc: return "ellipsis.circle.fill"
        }
    }
}
