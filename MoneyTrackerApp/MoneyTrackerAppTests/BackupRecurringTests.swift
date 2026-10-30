//
//  BackupRecurringTests.swift
//  MoneyTrackerAppTests
//
//  Schedules and skip markers survive a backup round trip; pre-v4 backups migrate on import.
//

import CoreData
import Foundation
import Testing
@testable import MoneyTrackerApp

@Suite("Backup with recurring schedules")
@MainActor // viewContext is main-queue bound; Swift Testing would otherwise run these on background threads
struct BackupRecurringTests {
    private typealias F = RecurringFixtures

    @Test("Round trip keeps schedules, links and deleted logs")
    func roundTrip() throws {
        let source = F.makeContext()
        let schedule = F.makeSchedule(in: source, interval: .daily, start: F.date(2026, 10, 26))
        let scheduleId = schedule.id
        F.generate(in: source, asOf: F.date(2026, 10, 28))
        try F.deleteLog(F.logs(in: source, scheduleId: scheduleId)[1], in: source)

        let url = try #require(BackupManager.exportToFile(context: source))
        defer { try? FileManager.default.removeItem(at: url) }

        let restored = F.makeContext()
        F.makeLog(in: restored, date: F.date(2020, 1, 1)) // existing data is replaced
        try restored.save()
        #expect(BackupManager.importFromFile(url: url, context: restored) == nil)
        try restored.save()

        let restoredSchedule = try #require(F.schedules(in: restored).first)
        #expect(restoredSchedule.id == scheduleId)
        #expect(restoredSchedule.interval == .daily)
        #expect(F.skipMarkers(in: restored).count == 1)

        F.generate(in: restored, asOf: F.date(2026, 10, 29))
        #expect(F.days(F.logs(in: restored, scheduleId: scheduleId)) == [
            F.date(2026, 10, 26), F.date(2026, 10, 28), F.date(2026, 10, 29)
        ])
        #expect(F.allLogs(in: restored).count == 3)
    }

    @Test("A v3 backup (template on a transaction) is migrated to a schedule on import")
    func v3BackupMigrates() throws {
        let groupId = UUID()
        let template = BackupTransaction(
            id: UUID(), date: F.date(2026, 8, 15), amount: 10, categoryRaw: MoneyCategory.subscriptions.rawValue,
            merchant: "Spotify", paymentMethodRaw: PaymentMethod.credit.rawValue, notes: nil,
            typeRaw: TransactionType.expense.rawValue, isRecurring: true,
            recurringIntervalRaw: RecurringInterval.monthly.rawValue, recurringGroupId: groupId,
            generatedFromRecurringId: nil, occurrenceDate: nil, isScheduleOnly: false,
            createdAt: Date(), originalCurrencyRaw: "USD", originalAmount: 10
        )
        let backup = BackupData(
            version: 3, exportedAt: Date(), transactions: [template], presets: [], budgets: [],
            skippedOccurrences: [], schedules: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("v3-\(UUID()).json")
        try encoder.encode(backup).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let context = F.makeContext()
        #expect(BackupManager.importFromFile(url: url, context: context) == nil)
        try context.save()

        let schedule = try #require(F.schedules(in: context).first)
        #expect(schedule.id == groupId)
        F.generate(in: context, asOf: F.date(2026, 10, 20))
        #expect(F.logs(in: context, scheduleId: groupId).count == 3)
    }
}
