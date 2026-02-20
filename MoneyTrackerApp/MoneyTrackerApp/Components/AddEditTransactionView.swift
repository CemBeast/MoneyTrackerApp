import SwiftUI
import CoreData

struct AddEditTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var currencyViewModel: CurrencyViewModel

    let transaction: CDTransaction?
    let preset: CDPreset?
    let onSaved: (() -> Void)?

    @State private var date: Date
    @State private var amount: String
    @State private var category: MoneyCategory
    @State private var hasInitializedAmountFromCurrency = false
    @State private var merchant: String
    @State private var paymentMethod: PaymentMethod
    @State private var notes: String
    @State private var type: TransactionType
    @State private var recurringInterval: RecurringInterval?
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(transaction: CDTransaction? = nil, preset: CDPreset? = nil, onSaved: (() -> Void)? = nil) {
        self.transaction = transaction
        self.preset = preset
        self.onSaved = onSaved
        
        if let transaction = transaction {
            _date = State(initialValue: transaction.date)
            _amount = State(initialValue: "")  // set in onAppear from currencyViewModel (amount stored in USD)
            _category = State(initialValue: transaction.category)
            _merchant = State(initialValue: transaction.merchant ?? "")
            _paymentMethod = State(initialValue: transaction.paymentMethod)
            _notes = State(initialValue: transaction.notes ?? "")
            _type = State(initialValue: transaction.type)
            _recurringInterval = State(initialValue: transaction.recurringInterval)
        } else if let preset = preset {
            _date = State(initialValue: Date())
            _amount = State(initialValue: "")  // set in onAppear from currencyViewModel if preset has amount
            _category = State(initialValue: preset.defaultCategory)
            _merchant = State(initialValue: preset.defaultMerchant ?? "")
            _paymentMethod = State(initialValue: preset.defaultPaymentMethod)
            _notes = State(initialValue: preset.defaultNotes ?? "")
            _type = State(initialValue: .expense)
            _recurringInterval = State(initialValue: nil)
        } else {
            _date = State(initialValue: Date())
            _amount = State(initialValue: "")
            _category = State(initialValue: .misc)
            _merchant = State(initialValue: "")
            _paymentMethod = State(initialValue: .other)
            _notes = State(initialValue: "")
            _type = State(initialValue: .expense)
            _recurringInterval = State(initialValue: nil)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Amount Section
                        VStack(spacing: 12) {
                            CyberSectionHeader(title: "Amount")
                            
                            HStack {
                                Text(currencyViewModel.selectedCurrency.currencySymbol)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.neonGreen)

                                TextField("0.00", text: $amount)
                                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                                    .foregroundColor(.neonGreen)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding()
                            .cyberCard()
                        }
                        
                        // Details Section
                        VStack(spacing: 16) {
                            CyberSectionHeader(title: "Details")
                            
                            VStack(spacing: 12) {
                                CyberFormRow(label: "Date") {
                                    DatePicker("", selection: $date, displayedComponents: .date)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        .tint(.neonGreen)
                                }
                                
                                CyberDivider()
                                
                                CyberFormRow(label: "Category") {
                                    Picker("", selection: $category) {
                                        ForEach(MoneyCategory.allCases) { cat in
                                            Text(cat.rawValue).tag(cat)
                                        }
                                    }
                                    .tint(.neonGreen)
                                }
                                
                                CyberDivider()
                                
                                CyberFormRow(label: "Merchant") {
                                    TextField("Enter merchant", text: $merchant)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.trailing)
                                }
                                
                                CyberDivider()
                                
                                CyberFormRow(label: "Payment") {
                                    Picker("", selection: $paymentMethod) {
                                        ForEach(PaymentMethod.allCases) { method in
                                            Text(method.rawValue).tag(method)
                                        }
                                    }
                                    .tint(.neonGreen)
                                }
                                
                                CyberDivider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Notes")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    TextField("Add notes...", text: $notes, axis: .vertical)
                                        .foregroundColor(.white)
                                        .lineLimit(3...6)
                                }
                            }
                            .padding()
                            .cyberCard()
                        }
                        
                        // Recurring Section
                        VStack(spacing: 16) {
                            CyberSectionHeader(title: "Recurring")
                            
                            VStack(spacing: 12) {
                                CyberFormRow(label: "How Often") {
                                    Picker("", selection: $recurringInterval) {
                                        Text("None").tag(nil as RecurringInterval?)
                                        ForEach(RecurringInterval.allCases) { interval in
                                            Text(interval.rawValue.capitalized).tag(interval as RecurringInterval?)
                                        }
                                    }
                                    .tint(.neonGreen)
                                }
                                
                                if recurringInterval == .monthly {
                                    CyberDivider()
                                    
                                    Text("Monthly repeats on day \(Calendar.current.component(.day, from: date)), using the last day when needed.")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding()
                            .cyberCard()
                        }
                        
                        // Save Button
                        Button {
                            save()
                        } label: {
                            Text("Save Transaction")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.cyberBlack)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.neonGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .neonGreenGlow, radius: 10)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .cyberNavTitle(transaction == nil ? "Add Transaction" : "Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.neonGreen)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                guard !hasInitializedAmountFromCurrency else { return }
                if let t = transaction {
                    amount = String(format: "%.2f", currencyViewModel.convertFromBase(t.amount))
                } else if let p = preset, p.defaultAmount > 0 {
                    amount = String(format: "%.2f", currencyViewModel.convertFromBase(p.defaultAmount))
                }
                hasInitializedAmountFromCurrency = true
            }
        }
    }

    private func save() {
        guard let amountInDisplayCurrency = Double(amount), amountInDisplayCurrency > 0 else {
            errorMessage = "Amount must be greater than 0"
            showError = true
            return
        }

        let amountInBase = currencyViewModel.convertToBase(amountInDisplayCurrency)

        let context = transaction?.managedObjectContext ?? viewContext
        let txn: CDTransaction
        let isRecurring = recurringInterval != nil

        if let transaction = transaction {
            txn = transaction
        } else {
            txn = CDTransaction(context: context)
            txn.id = UUID()
            txn.createdAt = Date()
        }

        // Update transaction properties (amount stored in USD)
        txn.date = date
        txn.amount = amountInBase
        txn.categoryRaw = category.rawValue
        txn.merchant = merchant.isEmpty ? nil : merchant
        txn.paymentMethodRaw = paymentMethod.rawValue
        txn.notes = notes.isEmpty ? nil : notes
        txn.typeRaw = type.rawValue
        txn.isRecurring = isRecurring
        txn.recurringIntervalRaw = recurringInterval?.rawValue
        
        // Generated instances should keep their source IDs untouched.
        if txn.generatedFromRecurringId == nil {
            if isRecurring {
                if txn.recurringGroupId == nil {
                    txn.recurringGroupId = UUID()
                }
            } else {
                txn.recurringGroupId = nil
            }
        }
        
        // Ensure the object is marked as updated
        if context.hasChanges {
            // Save to context - this will trigger CoreData notifications
            PersistenceController.shared.save(context)
        }
        
        // Notify parent
        onSaved?()
        // Dismiss immediately - CoreData will automatically update all views
        dismiss()
    }
}

// MARK: - Cyber Form Row
struct CyberFormRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            content
        }
    }
}
