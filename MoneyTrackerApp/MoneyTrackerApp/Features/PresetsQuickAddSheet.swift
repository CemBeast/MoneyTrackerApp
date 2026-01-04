import SwiftUI
import CoreData

struct PresetsQuickAddSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDPreset.name, ascending: true)])
    private var presets: FetchedResults<CDPreset>
    
    @State private var showAddPreset = false
    @State private var showAddTransaction = false
    @State private var selectedPreset: CDPreset?
    @State private var presetToEdit: CDPreset?
    @State private var toastMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        if presets.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "bolt.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.neonGreen.opacity(0.3))
                                
                                Text("No presets yet")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text("Create presets for quick transaction entry")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.3))
                                    .multilineTextAlignment(.center)
                                
                                Button {
                                    showAddPreset = true
                                } label: {
                                    Text("Create Preset")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.cyberBlack)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Color.neonGreen)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .padding(.top, 8)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(presets) { preset in
                                CyberPresetRow(preset: preset) {
                                    handlePresetTap(preset)
                                }
                                .contextMenu {
                                    Button {
                                        presetToEdit = preset
                                        showAddPreset = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        deletePreset(preset)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .cyberNavTitle("Quick Add")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.neonGreen)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddPreset = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.neonGreen)
                    }
                }
            }
            .sheet(isPresented: $showAddPreset) {
                CyberAddPresetView(preset: presetToEdit)
                    .onDisappear { presetToEdit = nil }
            }
            .sheet(isPresented: $showAddTransaction) {
                if let preset = selectedPreset {
                    AddEditTransactionView(preset: preset)
                }
            }
            .toast(isPresented: Binding(get: { toastMessage != nil }, set: { _ in toastMessage = nil })) {
                Toast(text: toastMessage ?? "")
            }
        }
    }
    
    private func deletePreset(_ preset: CDPreset) {
        viewContext.delete(preset)
        PersistenceController.shared.save(viewContext)
    }
    
    private func handlePresetTap(_ preset: CDPreset) {
        // If preset has an amount, create transaction immediately; otherwise open add form
        if preset.defaultAmount > 0 {
            createTransaction(from: preset)
            toastMessage = "Added \(preset.name) to log"
        } else {
            selectedPreset = preset
            showAddTransaction = true
        }
    }
    
    private func createTransaction(from preset: CDPreset) {
        let txn = CDTransaction(context: viewContext)
        txn.id = UUID()
        txn.createdAt = Date()
        txn.date = Date()
        txn.amount = preset.defaultAmount
        txn.categoryRaw = preset.defaultCategoryRaw
        txn.merchant = preset.defaultMerchant
        txn.paymentMethodRaw = preset.defaultPaymentMethodRaw
        txn.notes = preset.defaultNotes
        txn.typeRaw = TransactionType.expense.rawValue
        txn.isRecurring = false
        txn.recurringIntervalRaw = nil
        PersistenceController.shared.save(viewContext)
    }
}

struct CyberPresetRow: View {
    let preset: CDPreset
    let onTap: () -> Void
    
    private var categoryColor: Color {
        switch preset.defaultCategory {
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
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.neonGreen.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.neonGreen)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(preset.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        CyberTag(text: preset.defaultCategory.rawValue, color: categoryColor)
                        
                        if let merchant = preset.defaultMerchant, !merchant.isEmpty {
                            Text(merchant)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                
                Spacer()
                
                if preset.defaultAmount > 0 {
                    Text(preset.defaultAmount.currency())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.neonGreen)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.neonGreen.opacity(0.5))
            }
            .padding(14)
            .background(Color.cyberDarkGray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.neonGreen.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct CyberAddPresetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let preset: CDPreset?
    
    @State private var name = ""
    @State private var defaultCategory: MoneyCategory = .misc
    @State private var defaultMerchant = ""
    @State private var defaultPaymentMethod: PaymentMethod = .other
    @State private var defaultNotes = ""
    @State private var defaultAmount: String = ""
    
    init(preset: CDPreset? = nil) {
        self.preset = preset
        _name = State(initialValue: preset?.name ?? "")
        _defaultCategory = State(initialValue: preset?.defaultCategory ?? .misc)
        _defaultMerchant = State(initialValue: preset?.defaultMerchant ?? "")
        _defaultPaymentMethod = State(initialValue: preset?.defaultPaymentMethod ?? .other)
        _defaultNotes = State(initialValue: preset?.defaultNotes ?? "")
        _defaultAmount = State(initialValue: preset.map { $0.defaultAmount > 0 ? String($0.defaultAmount) : "" } ?? "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Name
                        VStack(alignment: .leading, spacing: 12) {
                            CyberSectionHeader(title: "Preset Name")
                            
                            TextField("Enter name", text: $name)
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.cyberGray)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.neonGreen.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Details
                        VStack(spacing: 16) {
                            CyberSectionHeader(title: "Default Values")
                            
                            VStack(spacing: 12) {
                                CyberFormRow(label: "Category") {
                                    Picker("", selection: $defaultCategory) {
                                        ForEach(MoneyCategory.allCases) { cat in
                                            Text(cat.rawValue).tag(cat)
                                        }
                                    }
                                    .tint(.neonGreen)
                                }
                                
                                CyberDivider()
                                
                                CyberFormRow(label: "Merchant") {
                                    TextField("Optional", text: $defaultMerchant)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.trailing)
                                }
                                
                                CyberDivider()
                                
                                CyberFormRow(label: "Payment") {
                                    Picker("", selection: $defaultPaymentMethod) {
                                        ForEach(PaymentMethod.allCases) { method in
                                            Text(method.rawValue).tag(method)
                                        }
                                    }
                                    .tint(.neonGreen)
                                }
                                
                                CyberDivider()
                                
                                CyberFormRow(label: "Amount") {
                                    HStack(spacing: 4) {
                                        Text("$")
                                            .foregroundColor(.neonGreen.opacity(0.6))
                                        TextField("0.00", text: $defaultAmount)
                                            .keyboardType(.decimalPad)
                                            .foregroundColor(.neonGreen)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                                
                                CyberDivider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Notes")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    TextField("Optional notes...", text: $defaultNotes, axis: .vertical)
                                        .foregroundColor(.white)
                                        .lineLimit(3...6)
                                }
                            }
                            .padding()
                            .cyberCard()
                        }
                        
                        // Save button
                        Button {
                            save()
                        } label: {
                            Text(preset == nil ? "Save Preset" : "Update Preset")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.cyberBlack)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(name.isEmpty ? Color.cyberGray : Color.neonGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: name.isEmpty ? .clear : .neonGreenGlow, radius: 10)
                        }
                        .disabled(name.isEmpty)
                    }
                    .padding()
                }
            }
            .cyberNavTitle(preset == nil ? "New Preset" : "Edit Preset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.neonGreen)
                }
            }
        }
    }
    
    private func save() {
        let preset = CDPreset(context: viewContext)
        preset.id = UUID()
        preset.name = name
        preset.defaultCategoryRaw = defaultCategory.rawValue
        preset.defaultMerchant = defaultMerchant.isEmpty ? nil : defaultMerchant
        preset.defaultPaymentMethodRaw = defaultPaymentMethod.rawValue
        preset.defaultNotes = defaultNotes.isEmpty ? nil : defaultNotes
        preset.defaultAmount = Double(defaultAmount) ?? 0
        
        PersistenceController.shared.save(viewContext)
        dismiss()
    }
}
