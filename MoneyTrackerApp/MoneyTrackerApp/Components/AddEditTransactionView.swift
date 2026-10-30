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
    @State private var showMakeRecurring = false

    /// When editing an existing log, this is the currency the transaction was originally logged in.
    /// The amount input is shown/saved in this currency, not the user's current display currency.
    /// Nil when creating a new transaction (uses the user's selected display currency).
    @State private var entryCurrency: AppCurrency? = nil
    
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
        } else if let preset = preset {
            _date = State(initialValue: Date())
            _amount = State(initialValue: "")  // set in onAppear from currencyViewModel if preset has amount
            _category = State(initialValue: preset.defaultCategory)
            _merchant = State(initialValue: preset.defaultMerchant ?? "")
            _paymentMethod = State(initialValue: preset.defaultPaymentMethod)
            _notes = State(initialValue: preset.defaultNotes ?? "")
            _type = State(initialValue: .expense)
        } else {
            _date = State(initialValue: Date())
            _amount = State(initialValue: "")
            _category = State(initialValue: .misc)
            _merchant = State(initialValue: "")
            _paymentMethod = State(initialValue: .other)
            _notes = State(initialValue: "")
            _type = State(initialValue: .expense)
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
                                Text(activeCurrency.currencySymbol)
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

                            if let entryCurrency, entryCurrency != currencyViewModel.selectedCurrency {
                                Text("Logged in \(entryCurrency.label) — editing in original currency.")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                            }
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
                        
                        // Recurring Section (schedules are managed in Settings → Recurring)
                        if let transaction {
                            VStack(spacing: 16) {
                                CyberSectionHeader(title: "Recurring")

                                if transaction.isGeneratedFromSchedule {
                                    HStack(spacing: 12) {
                                        Image(systemName: "repeat.circle.fill")
                                            .foregroundColor(.neonGreen)
                                        Text("Part of recurring (\((transaction.recurringInterval?.rawValue ?? "recurring").capitalized)). Edits here only change this log.")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding()
                                    .cyberCard()
                                } else {
                                    Button {
                                        showMakeRecurring = true
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "repeat")
                                            Text("Make Recurring")
                                                .fontWeight(.semibold)
                                            Spacer()
                                        }
                                        .foregroundColor(.neonGreen)
                                        .padding()
                                        .cyberCard()
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
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
            .confirmationDialog("Repeat this transaction", isPresented: $showMakeRecurring, titleVisibility: .visible) {
                ForEach(RecurringInterval.allCases) { interval in
                    Button(interval.rawValue.capitalized) {
                        save(makingRecurring: interval)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Creates a schedule in Settings → Recurring starting on this log's date. This log stays as the first one.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                guard !hasInitializedAmountFromCurrency else { return }
                if let t = transaction {
                    if t.hasCurrencySnapshot {
                        // Edit in the transaction's original currency.
                        entryCurrency = t.originalCurrency
                        amount = String(format: "%.2f", t.originalAmount)
                    } else {
                        // Legacy row: amount is USD. Show in USD.
                        entryCurrency = .usd
                        amount = String(format: "%.2f", t.amount)
                    }
                } else if let p = preset, p.defaultAmount > 0 {
                    // Presets store defaultAmount in USD; show converted into current display currency.
                    amount = String(format: "%.2f", currencyViewModel.convertFromBase(p.defaultAmount))
                }
                hasInitializedAmountFromCurrency = true
            }
        }
    }

    /// Currency the input is being entered in. For edits, the transaction's original currency; otherwise the user's display currency.
    private var activeCurrency: AppCurrency {
        entryCurrency ?? currencyViewModel.selectedCurrency
    }

    /// Saves the form. With `interval`, also turns the saved log into the first occurrence of a new schedule.
    private func save(makingRecurring interval: RecurringInterval? = nil) {
        guard let enteredAmount = Double(amount), enteredAmount > 0 else {
            errorMessage = "Amount must be greater than 0"
            showError = true
            return
        }

        // Snapshot the original currency + frozen USD-equivalent at save time.
        let originalCurrency = activeCurrency
        let rateToUSD = currencyViewModel.rateToUSD(for: originalCurrency)
        let frozenUSD = enteredAmount * rateToUSD

        let context = transaction?.managedObjectContext ?? viewContext
        let txn: CDTransaction

        if let transaction = transaction {
            txn = transaction
        } else {
            txn = CDTransaction(context: context)
            txn.id = UUID()
            txn.createdAt = Date()
        }

        // Update transaction properties. amount = frozen USD-equivalent at save time.
        txn.date = date
        txn.amount = frozenUSD
        txn.originalCurrencyRaw = originalCurrency.rawValue
        txn.originalAmount = enteredAmount
        txn.categoryRaw = category.rawValue
        txn.merchant = merchant.isEmpty ? nil : merchant
        txn.paymentMethodRaw = paymentMethod.rawValue
        txn.notes = notes.isEmpty ? nil : notes
        txn.typeRaw = type.rawValue

        if let interval, !txn.isGeneratedFromSchedule {
            RecurringEngine.makeSchedule(from: txn, interval: interval, in: context)
        }

        // Ensure the object is marked as updated
        if context.hasChanges {
            // Save to context - this will trigger CoreData notifications
            PersistenceController.shared.save(context)
        }

        // A back-dated schedule should catch up now, not on next launch.
        if interval != nil {
            RecurringEngine(context: context, currencyViewModel: currencyViewModel).generateDueTransactions()
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
