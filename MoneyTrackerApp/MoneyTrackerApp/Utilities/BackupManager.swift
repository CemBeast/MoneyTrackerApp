//
//  BackupManager.swift
//  MoneyTrackerApp
//
//  Exports and imports all app data to/from JSON for backup and restore.
//

import CoreData
import Foundation
import UniformTypeIdentifiers

// MARK: - Backup data structures

struct BackupData: Codable {
    let version: Int
    let exportedAt: Date
    let transactions: [BackupTransaction]
    let presets: [BackupPreset]
    let budgets: [BackupBudget]

    static let currentVersion = 1
}

struct BackupTransaction: Codable {
    let id: UUID
    let date: Date
    let amount: Double
    let categoryRaw: String
    let merchant: String?
    let paymentMethodRaw: String?
    let notes: String?
    let typeRaw: Int16
    let isRecurring: Bool
    let recurringIntervalRaw: String?
    let recurringGroupId: UUID?
    let generatedFromRecurringId: UUID?
    let createdAt: Date
}

struct BackupPreset: Codable {
    let id: UUID
    let name: String
    let defaultCategoryRaw: String
    let defaultMerchant: String?
    let defaultPaymentMethodRaw: String?
    let defaultNotes: String?
    let defaultAmount: Double
}

struct BackupBudget: Codable {
    let id: UUID
    let monthStart: Date
    let categoryRaw: String
    let limit: Double
}

// MARK: - Backup Manager

enum BackupManager {

    /// Exports all transactions, presets, and budgets to a JSON file. Returns the file URL or nil on failure.
    static func exportToFile(context: NSManagedObjectContext) -> URL? {
        let txnRequest = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        txnRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: true)]

        let presetRequest = NSFetchRequest<CDPreset>(entityName: "CDPreset")
        presetRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDPreset.name, ascending: true)]

        let budgetRequest = NSFetchRequest<CDBudget>(entityName: "CDBudget")
        budgetRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDBudget.monthStart, ascending: true)]

        guard let transactions = try? context.fetch(txnRequest),
              let presets = try? context.fetch(presetRequest),
              let budgets = try? context.fetch(budgetRequest) else {
            return nil
        }

        let backup = BackupData(
            version: BackupData.currentVersion,
            exportedAt: Date(),
            transactions: transactions.map { t in
                BackupTransaction(
                    id: t.id,
                    date: t.date,
                    amount: t.amount,
                    categoryRaw: t.categoryRaw,
                    merchant: t.merchant,
                    paymentMethodRaw: t.paymentMethodRaw,
                    notes: t.notes,
                    typeRaw: t.typeRaw,
                    isRecurring: t.isRecurring,
                    recurringIntervalRaw: t.recurringIntervalRaw,
                    recurringGroupId: t.recurringGroupId,
                    generatedFromRecurringId: t.generatedFromRecurringId,
                    createdAt: t.createdAt
                )
            },
            presets: presets.map { p in
                BackupPreset(
                    id: p.id,
                    name: p.name,
                    defaultCategoryRaw: p.defaultCategoryRaw,
                    defaultMerchant: p.defaultMerchant,
                    defaultPaymentMethodRaw: p.defaultPaymentMethodRaw,
                    defaultNotes: p.defaultNotes,
                    defaultAmount: p.defaultAmount
                )
            },
            budgets: budgets.map { b in
                BackupBudget(
                    id: b.id,
                    monthStart: b.monthStart,
                    categoryRaw: b.categoryRaw,
                    limit: b.limit
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(backup) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "MoneyTracker_backup_\(timestamp).json"

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try? data.write(to: fileURL)
        return fileURL
    }

    /// Imports data from a backup file. Replaces all existing data. Returns error message on failure.
    static func importFromFile(url: URL, context: NSManagedObjectContext) -> String? {
        guard let data = try? Data(contentsOf: url) else {
            return "Could not read file"
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let backup = try? decoder.decode(BackupData.self, from: data) else {
            return "Invalid backup file format"
        }

        // Delete existing data (individual deletes to keep context in sync)
        let txnRequest = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        (try? context.fetch(txnRequest))?.forEach { context.delete($0) }
        let presetRequest = NSFetchRequest<CDPreset>(entityName: "CDPreset")
        (try? context.fetch(presetRequest))?.forEach { context.delete($0) }
        let budgetRequest = NSFetchRequest<CDBudget>(entityName: "CDBudget")
        (try? context.fetch(budgetRequest))?.forEach { context.delete($0) }

        // Insert transactions
        for t in backup.transactions {
            let obj = CDTransaction(context: context)
            obj.id = t.id
            obj.date = t.date
            obj.amount = t.amount
            obj.categoryRaw = t.categoryRaw
            obj.merchant = t.merchant
            obj.paymentMethodRaw = t.paymentMethodRaw
            obj.notes = t.notes
            obj.typeRaw = t.typeRaw
            obj.isRecurring = t.isRecurring
            obj.recurringIntervalRaw = t.recurringIntervalRaw
            obj.recurringGroupId = t.recurringGroupId
            obj.generatedFromRecurringId = t.generatedFromRecurringId
            obj.createdAt = t.createdAt
        }

        // Insert presets
        for p in backup.presets {
            let obj = CDPreset(context: context)
            obj.id = p.id
            obj.name = p.name
            obj.defaultCategoryRaw = p.defaultCategoryRaw
            obj.defaultMerchant = p.defaultMerchant
            obj.defaultPaymentMethodRaw = p.defaultPaymentMethodRaw
            obj.defaultNotes = p.defaultNotes
            obj.defaultAmount = p.defaultAmount
        }

        // Insert budgets
        for b in backup.budgets {
            let obj = CDBudget(context: context)
            obj.id = b.id
            obj.monthStart = b.monthStart
            obj.categoryRaw = b.categoryRaw
            obj.limit = b.limit
        }

        return nil
    }
}
