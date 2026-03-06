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
        startDate: Date? = nil,
        endDate: Date? = nil,
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
        
        // Month filter (only applies when no custom date range is set)
        if startDate == nil && endDate == nil, let month = month {
            let mStart = month.startDate
            let mEnd = Calendar.current.date(byAdding: .month, value: 1, to: mStart) ?? mStart
            predicates.append(NSPredicate(format: "date >= %@ AND date < %@", mStart as NSDate, mEnd as NSDate))
        }
        
        // Custom date range
        if let startDate = startDate {
            let startOfDay = Calendar.current.startOfDay(for: startDate)
            predicates.append(NSPredicate(format: "date >= %@", startOfDay as NSDate))
        }
        if let endDate = endDate {
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
            predicates.append(NSPredicate(format: "date < %@", endOfDay as NSDate))
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
    var showRecurringBadge: Bool = true  // Show recurring indicator when transaction.isRecurring

    private var shouldShowRecurring: Bool {
        showRecurringBadge && (transaction.isRecurring || transaction.generatedFromRecurringId != nil)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(categoryColor.opacity(0.5), lineWidth: 1)
                    )

                Image(systemName: categoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(transaction.merchant ?? "No merchant")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Text(transaction.date, style: .date)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }

                HStack(alignment: .firstTextBaseline) {
                    if let notes = transaction.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(currencyViewModel.format(amountInBase: transaction.amount))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.neonGreen)
                }

                HStack(spacing: 8) {
                    CyberTag(text: transaction.category.rawValue, color: categoryColor)

                    if shouldShowRecurring {
                        CyberTag(
                            text: (transaction.recurringInterval?.rawValue ?? "recurring").capitalized,
                            color: .neonGreen
                        )
                    }

                    Text(transaction.paymentMethod.rawValue)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.cyberDarkGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(categoryColor.opacity(0.2), lineWidth: 1)
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
