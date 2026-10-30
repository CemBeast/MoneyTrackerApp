//
//  LegacyRecurringMigrationTests.swift
//  MoneyTrackerAppTests
//
//  Pre-schedule data (template = first log) converts to schedules without losing or resurrecting logs.
//

import CoreData
import Foundation
import Testing
@testable import MoneyTrackerApp

@Suite("Legacy recurring migration")
@MainActor // viewContext is main-queue bound; Swift Testing would otherwise run these on background threads
struct LegacyRecurringMigrationTests {
    private typealias F = RecurringFixtures

    @Test("A template becomes a schedule, and its row becomes the first log with no duplicate")
    func templateBecomesSchedule() throws {
        let context = F.makeContext()
        let groupId = UUID()
        let template = F.makeLegacyTemplate(in: context, interval: .monthly, date: F.date(2026, 8, 15, hour: 14), groupId: groupId)
        let templateId = template.id
        F.makeLegacyInstance(in: context, groupId: groupId, date: F.date(2026, 9, 15, hour: 14))
        try context.save()

        F.generate(in: context, asOf: F.date(2026, 10, 20))

        let schedule = try #require(F.schedules(in: context).first)
        #expect(F.schedules(in: context).count == 1)
        #expect(schedule.id == groupId, "Schedule reuses the group id so existing links survive")
        #expect(schedule.interval == .monthly)
        #expect(schedule.startDate == F.date(2026, 8, 15))

        let logs = F.logs(in: context, scheduleId: groupId)
        #expect(F.days(logs) == [F.date(2026, 8, 15), F.date(2026, 9, 15), F.date(2026, 10, 15)])
        #expect(logs.first?.id == templateId)
        #expect(logs.allSatisfy { !$0.isRecurring && $0.occurrenceDate != nil && $0.recurringInterval == .monthly })
    }

    @Test("A template whose first log was deleted doesn't bring that log back")
    func scheduleOnlyTemplateStaysDeleted() throws {
        let context = F.makeContext()
        let groupId = UUID()
        F.makeLegacyTemplate(in: context, interval: .daily, date: F.date(2026, 10, 28), groupId: groupId, scheduleOnly: true)
        F.makeLegacyInstance(in: context, groupId: groupId, date: F.date(2026, 10, 29))
        try context.save()

        F.generate(in: context, asOf: F.date(2026, 10, 30))

        #expect(F.schedules(in: context).count == 1)
        #expect(F.days(F.logs(in: context, scheduleId: groupId)) == [F.date(2026, 10, 29), F.date(2026, 10, 30)])
        #expect(F.allLogs(in: context).count == 2, "The hidden template row is gone")
    }

    @Test("Existing skip markers keep working after migration")
    func existingSkipMarkersHonored() throws {
        let context = F.makeContext()
        let groupId = UUID()
        F.makeLegacyTemplate(in: context, interval: .daily, date: F.date(2026, 10, 27), groupId: groupId)
        let skipped = CDSkippedOccurrence(context: context)
        skipped.id = UUID()
        skipped.groupId = groupId
        skipped.date = F.date(2026, 10, 28)
        try context.save()

        F.generate(in: context, asOf: F.date(2026, 10, 29))

        #expect(F.days(F.logs(in: context, scheduleId: groupId)) == [F.date(2026, 10, 27), F.date(2026, 10, 29)])
    }

    @Test("Migration is idempotent")
    func idempotent() throws {
        let context = F.makeContext()
        let groupId = UUID()
        F.makeLegacyTemplate(in: context, interval: .weekly, date: F.date(2026, 10, 7), groupId: groupId)
        try context.save()

        LegacyRecurringMigration.run(in: context)
        LegacyRecurringMigration.run(in: context)
        F.generate(in: context, asOf: F.date(2026, 10, 30))
        F.generate(in: context, asOf: F.date(2026, 10, 30))

        #expect(F.schedules(in: context).count == 1)
        #expect(F.logs(in: context, scheduleId: groupId).count == 4)
    }

    @Test("A legacy recurring row with no interval just becomes a normal log")
    func templateWithoutIntervalIsDropped() throws {
        let context = F.makeContext()
        let template = F.makeLegacyTemplate(in: context, interval: .monthly, date: F.date(2026, 10, 1))
        template.recurringIntervalRaw = nil
        try context.save()

        F.generate(in: context, asOf: F.date(2026, 12, 1))

        #expect(F.schedules(in: context).isEmpty)
        #expect(F.allLogs(in: context).count == 1)
        #expect(template.isRecurring == false)
    }

    @Test("A log whose recurrence was removed earlier stays a normal log")
    func previouslyStoppedTemplateUntouched() throws {
        let context = F.makeContext()
        let log = F.makeLegacyTemplate(in: context, interval: .monthly, date: F.date(2026, 8, 1))
        log.isRecurring = false
        log.recurringIntervalRaw = nil
        try context.save()

        F.generate(in: context, asOf: F.date(2026, 12, 1))

        #expect(F.schedules(in: context).isEmpty)
        #expect(F.allLogs(in: context).count == 1)
        #expect(log.generatedFromRecurringId == nil)
    }
}
