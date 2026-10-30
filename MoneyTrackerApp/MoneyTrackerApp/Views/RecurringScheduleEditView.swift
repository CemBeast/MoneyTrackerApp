//
//  RecurringScheduleEditView.swift
//  MoneyTrackerApp
//
//  Creates or edits a recurring schedule. Edits only affect logs generated from now on;
//  logs already in the Transaction Log are independent copies.
//

import SwiftUI
import CoreData

struct RecurringScheduleEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var currencyViewModel: CurrencyViewModel

    let schedule: CDRecurringSchedule?

    @State private var amount: String = ""
    @State private var interval: RecurringInterval
    @State private var startDate: Date
    @State private var category: MoneyCategory
    @State private var merchant: String
    @State private var paymentMethod: PaymentMethod
    @State private var notes: String
    @State private var hasInitializedAmount = false

    /// Currency the amount is entered in. For edits, the schedule's original currency; otherwise the display currency.
    @State private var entryCurrency: AppCurrency? = nil

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRemoveConfirm = false

    init(schedule: CDRecurringSchedule? = nil) {
        self.schedule = schedule
        _interval = State(initialValue: schedule?.interval ?? .monthly)
        _startDate = State(initialValue: schedule?.startDate ?? Date())
        _category = State(initialValue: schedule?.category ?? .subscriptions)
        _merchant = State(initialValue: schedule?.merchant ?? "")
        _paymentMethod = State(initialValue: schedule?.paymentMethod ?? .other)
        _notes = State(initialValue: schedule?.notes ?? "")
    }

    private var activeCurrency: AppCurrency {
        entryCurrency ?? currencyViewModel.selectedCurrency
    }

    var body: some View {
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
                    }

                    // Schedule Section
                    VStack(spacing: 16) {
                        CyberSectionHeader(title: "Schedule")

                        VStack(spacing: 12) {
                            CyberFormRow(label: "How Often") {
                                Picker("", selection: $interval) {
                                    ForEach(RecurringInterval.allCases) { interval in
                                        Text(interval.rawValue.capitalized).tag(interval)
                                    }
                                }
                                .tint(.neonGreen)
                            }

                            CyberDivider()

                            CyberFormRow(label: "Starts") {
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .tint(.neonGreen)
                            }

                            CyberDivider()

                            Text(scheduleSummary)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .cyberCard()
                    }

                    // Details Section
                    VStack(spacing: 16) {
                        CyberSectionHeader(title: "Details")

                        VStack(spacing: 12) {
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

                    Button {
                        save()
                    } label: {
                        Text(schedule == nil ? "Create Recurring" : "Save Changes")
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

                    if schedule != nil {
                        Button(role: .destructive) {
                            showRemoveConfirm = true
                        } label: {
                            Text("Remove Recurring")
                                .font(.headline)
                                .foregroundColor(.neonRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding()
            }
        }
        .cyberNavTitle(schedule == nil ? "New Recurring" : "Edit Recurring")
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("Remove Recurring?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("Remove Recurring", role: .destructive) {
                if let schedule {
                    RecurringEngine.removeSchedule(schedule, in: viewContext)
                    PersistenceController.shared.save(viewContext)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("No new transactions will be generated. Past logged transactions are kept.")
        }
        .onAppear {
            guard !hasInitializedAmount else { return }
            if let schedule {
                if schedule.hasCurrencySnapshot {
                    entryCurrency = schedule.originalCurrency
                    amount = String(format: "%.2f", schedule.originalAmount)
                } else {
                    // Legacy schedule: amount is USD.
                    entryCurrency = .usd
                    amount = String(format: "%.2f", schedule.amount)
                }
            }
            hasInitializedAmount = true
        }
    }

    private var scheduleSummary: String {
        let calendar = Calendar.current
        switch interval {
        case .daily:
            return "Logs every day, starting on the start date."
        case .weekly:
            let weekday = calendar.weekdaySymbols[calendar.component(.weekday, from: startDate) - 1]
            return "Logs every \(weekday), starting on the start date."
        case .monthly:
            return "Logs on day \(calendar.component(.day, from: startDate)) of each month, using the last day when needed."
        }
    }

    private func save() {
        guard let enteredAmount = Double(amount), enteredAmount > 0 else {
            errorMessage = "Amount must be greater than 0"
            showError = true
            return
        }

        let target: CDRecurringSchedule
        if let schedule {
            target = schedule
        } else {
            target = CDRecurringSchedule(context: viewContext)
            target.id = UUID()
            target.createdAt = Date()
            target.typeRaw = TransactionType.expense.rawValue
        }

        let currency = activeCurrency
        target.originalCurrencyRaw = currency.rawValue
        target.originalAmount = enteredAmount
        target.amount = enteredAmount * currencyViewModel.rateToUSD(for: currency)
        target.intervalRaw = interval.rawValue
        target.startDate = Calendar.current.startOfDay(for: startDate)
        target.categoryRaw = category.rawValue
        target.merchant = merchant.isEmpty ? nil : merchant
        target.paymentMethodRaw = paymentMethod.rawValue
        target.notes = notes.isEmpty ? nil : notes

        PersistenceController.shared.save(viewContext)

        // A back-dated start (or a moved start/frequency) should catch up now, not on next launch.
        RecurringEngine(context: viewContext, currencyViewModel: currencyViewModel).generateDueTransactions()
        dismiss()
    }
}
