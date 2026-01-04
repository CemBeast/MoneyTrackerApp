import SwiftUI
import CoreData

struct CategoriesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedCategory: MoneyCategory?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: false)],
        predicate: NSPredicate(format: "typeRaw == %d", TransactionType.expense.rawValue)
    )
    private var allTransactions: FetchedResults<CDTransaction>
    
    private var categoryTotals: [MoneyCategory: Double] {
        var totals: [MoneyCategory: Double] = [:]
        for transaction in allTransactions {
            let category = transaction.category
            totals[category, default: 0] += transaction.amount
        }
        return totals
    }
    
    private var grandTotal: Double {
        categoryTotals.values.reduce(0, +)
    }
    
    private func categoryColor(_ category: MoneyCategory) -> Color {
        switch category {
        case .housing: return .neonBlue
        case .fixedBills: return .neonRed
        case .food: return .neonOrange
        case .transportation: return .neonPurple
        case .healthcare: return .neonYellow
        case .funLifestyle: return .neonPink
        case .shopping: return .neonBlue
        case .subscriptions: return .neonGreen
        case .savings: return .neonGreen
        case .investing: return .neonPurple
        case .travel: return .neonOrange
        case .gifts: return .neonPink
        case .misc: return .white.opacity(0.7)
        }
    }
    
    private func categoryIcon(_ category: MoneyCategory) -> String {
        switch category {
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Total header
                        VStack(spacing: 8) {
                            Text("ALL-TIME SPENDING")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(2)
                            
                            Text(grandTotal.currency())
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(.neonGreen)
                                .shadow(color: .neonGreenGlow, radius: 10)
                                .id("total-\(allTransactions.count)-\(grandTotal)")
                        }
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .cyberCard()
                        .id("header-\(allTransactions.count)")
                        
                        // Categories grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(MoneyCategory.allCases) { category in
                                let total = categoryTotals[category] ?? 0
                                let percent = grandTotal > 0 ? (total / grandTotal) * 100 : 0
                                
                                NavigationLink(destination: CategoryDetailView(category: category)) {
                                    CyberCategoryCard(
                                        category: category,
                                        total: total,
                                        percent: percent,
                                        color: categoryColor(category),
                                        icon: categoryIcon(category)
                                    )
                                    .id("\(category.id)-\(total)-\(allTransactions.count)")
                                }
                            }
                        }
                        .id("categories-grid-\(allTransactions.count)")
                    }
                    .padding()
                }
            }
            .cyberNavTitle("Categories")
        }
    }
}

struct CyberCategoryCard: View {
    let category: MoneyCategory
    let total: Double
    let percent: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                
                Text(total.currency())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                if percent > 0 {
                    Text(String(format: "%.1f%%", percent))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding()
        .frame(height: 140)
        .background(Color.cyberDarkGray)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
