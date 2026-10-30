//
//  RecurringScheduleLifecycleTests.swift
//  MoneyTrackerAppTests
//
//  Deleting, moving, editing and removing: logs and schedules stay independent.
//

import CoreData
import Foundation
import Testing
@testable import MoneyTrackerApp

@Suite("Recurring schedule lifecycle")
@MainActor // viewContext is main-queue bound; Swift Testing would otherwise run these on background threads
struct RecurringScheduleLifecycleTests {
    private typealias F = RecurringFixtures

    // MARK: Deleting logs

    @Test("Deleting the first log removes only that log; the schedule and other logs stay")
    func deleteFirstLog() throws {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .daily, start: F.date(2026, 10, 28))
        F.generate(in: context, asOf: F.date(2026, 10, 30))

        let first = try #require(F.logs(in: context, scheduleId: schedule.id).first)
        try F.deleteLog(first, in: context)
        F.generate(in: context, asOf: F.date(2026, 10, 31))

        #expect(F.schedules(in: context).count == 1)
        #expect(F.days(F.logs(in: context, scheduleId: schedule.id)) == [
            F.date(2026, 10, 29), F.date(2026, 10, 30), F.date(2026, 10, 31)
        ])
    }

    @Test("A deleted middle log stays deleted across runs")
    func deleteMiddleLog() throws {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .monthly, start: F.date(2026, 8, 15))
        F.generate(in: context, asOf: F.date(2026, 10, 20))

        let september = F.logs(in: context, scheduleId: schedule.id)[1]
        try F.deleteLog(september, in: context)
        F.generate(in: context, asOf: F.date(2026, 10, 20))
        F.generate(in: context, asOf: F.date(2026, 10, 21))

        #expect(F.days(F.logs(in: context, scheduleId: schedule.id)) == [F.date(2026, 8, 15), F.date(2026, 10, 15)])
    }

    @Test("Undo (removing the skip marker) frees the period, and it's re-logged exactly once")
    func undoDeleteFreesPeriod() throws {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .daily, start: F.date(2026, 10, 28))
        F.generate(in: context, asOf: F.date(2026, 10, 30))

        let middle = F.logs(in: context, scheduleId: schedule.id)[1]
        let marker = try #require(RecurringEngine.recordSkippedOccurrence(for: middle, in: context))
        context.delete(middle)
        try context.save()

        context.delete(marker)
        try context.save()
        F.generate(in: context, asOf: F.date(2026, 10, 30))
        F.generate(in: context, asOf: F.date(2026, 10, 30))

        #expect(F.logs(in: context, scheduleId: schedule.id).count == 3)
    }

    @Test("Deleting a manual (non-recurring) log leaves no skip marker")
    func manualDeleteHasNoMarker() throws {
        let context = F.makeContext()
        let log = F.makeLog(in: context, date: F.date(2026, 10, 1))
        try context.save()

        #expect(RecurringEngine.recordSkippedOccurrence(for: log, in: context) == nil)
    }

    // MARK: Moving logs

    @Test("Moving a log to another period doesn't re-log its original period")
    func movedLogNotDuplicated() throws {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .monthly, start: F.date(2026, 8, 15))
        F.generate(in: context, asOf: F.date(2026, 10, 20))

        let september = F.logs(in: context, scheduleId: schedule.id)[1]
        september.date = F.date(2026, 10, 2)
        try context.save()
        F.generate(in: context, asOf: F.date(2026, 10, 20))

        #expect(F.logs(in: context, scheduleId: schedule.id).count == 3)
    }

    @Test("Moving then deleting a log keeps its original period deleted")
    func movedThenDeletedStaysDeleted() throws {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .monthly, start: F.date(2026, 8, 15))
        F.generate(in: context, asOf: F.date(2026, 10, 20))

        let september = F.logs(in: context, scheduleId: schedule.id)[1]
        september.date = F.date(2026, 10, 2)
        try context.save()
        try F.deleteLog(september, in: context)
        F.generate(in: context, asOf: F.date(2026, 10, 20))

        #expect(F.days(F.logs(in: context, scheduleId: schedule.id)) == [F.date(2026, 8, 15), F.date(2026, 10, 15)])
    }

    // MARK: Editing schedules

    @Test("Editing a schedule's amount only affects future logs")
    func editAmountAffectsFutureOnly() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .monthly, start: F.date(2026, 9, 1), amount: 10)
        F.generate(in: context, asOf: F.date(2026, 10, 20))

        schedule.amount = 12
        schedule.originalAmount = 12
        F.generate(in: context, asOf: F.date(2026, 11, 20))

        #expect(F.logs(in: context, scheduleId: schedule.id).map(\.amount) == [10, 10, 12])
    }

    @Test("Moving the start date earlier backfills missed occurrences without duplicating")
    func earlierStartBackfills() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .monthly, start: F.date(2026, 9, 15))
        F.generate(in: context, asOf: F.date(2026, 10, 20))

        schedule.startDate = F.date(2026, 7, 15)
        F.generate(in: context, asOf: F.date(2026, 10, 20))

        #expect(F.days(F.logs(in: context, scheduleId: schedule.id)) == [
            F.date(2026, 7, 15), F.date(2026, 8, 15), F.date(2026, 9, 15), F.date(2026, 10, 15)
        ])
    }

    @Test("Changing the weekday of a weekly schedule doesn't double-log weeks that already have a log")
    func weekdayChangeNoDuplicateWeeks() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .weekly, start: F.date(2026, 10, 5)) // Monday
        F.generate(in: context, asOf: F.date(2026, 10, 14))

        schedule.startDate = F.date(2026, 10, 7) // Wednesday
        F.generate(in: context, asOf: F.date(2026, 10, 30))

        #expect(F.days(F.logs(in: context, scheduleId: schedule.id)) == [
            F.date(2026, 10, 5), F.date(2026, 10, 12), F.date(2026, 10, 21), F.date(2026, 10, 28)
        ])
    }

    @Test("Moving the start date later leaves earlier logs in place")
    func laterStartKeepsPastLogs() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .monthly, start: F.date(2026, 8, 15))
        F.generate(in: context, asOf: F.date(2026, 10, 20))

        schedule.startDate = F.date(2026, 12, 1)
        F.generate(in: context, asOf: F.date(2026, 11, 20))

        #expect(F.logs(in: context, scheduleId: schedule.id).count == 3)
    }

    // MARK: Removing schedules

    @Test("Removing a schedule keeps past logs, stops new ones, and cleans up its skip markers")
    func removeScheduleKeepsPast() throws {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .monthly, start: F.date(2026, 7, 15))
        let scheduleId = schedule.id
        F.generate(in: context, asOf: F.date(2026, 10, 20))
        try F.deleteLog(F.logs(in: context, scheduleId: scheduleId)[0], in: context)

        RecurringEngine.removeSchedule(schedule, in: context)
        try context.save()
        F.generate(in: context, asOf: F.date(2027, 3, 1))

        let past = F.logs(in: context, scheduleId: scheduleId)
        #expect(F.days(past) == [F.date(2026, 8, 15), F.date(2026, 9, 15), F.date(2026, 10, 15)])
        #expect(past.allSatisfy { $0.recurringInterval == .monthly }, "Past logs keep their badge")
        #expect(F.schedules(in: context).isEmpty)
        #expect(F.skipMarkers(in: context).isEmpty)
    }

    @Test("Removing one schedule doesn't touch another")
    func removeOnlyAffectsItself() throws {
        let context = F.makeContext()
        let a = F.makeSchedule(in: context, interval: .daily, start: F.date(2026, 10, 28))
        let b = F.makeSchedule(in: context, interval: .daily, start: F.date(2026, 10, 28), merchant: "Coffee")
        F.generate(in: context, asOf: F.date(2026, 10, 29))
        try F.deleteLog(F.logs(in: context, scheduleId: b.id)[0], in: context)

        RecurringEngine.removeSchedule(a, in: context)
        try context.save()
        F.generate(in: context, asOf: F.date(2026, 10, 30))

        #expect(F.days(F.logs(in: context, scheduleId: b.id)) == [F.date(2026, 10, 29), F.date(2026, 10, 30)])
        #expect(F.skipMarkers(in: context).count == 1)
    }

    // MARK: Make Recurring

    @Test("Make Recurring links the log as the first occurrence without duplicating it")
    func makeRecurringFromLog() throws {
        let context = F.makeContext()
        let log = F.makeLog(in: context, date: F.date(2026, 8, 15, hour: 15), amount: 9.99)
        let logId = log.id

        let schedule = RecurringEngine.makeSchedule(from: log, interval: .monthly, in: context)
        try context.save()
        F.generate(in: context, asOf: F.date(2026, 10, 20))

        let logs = F.logs(in: context, scheduleId: schedule.id)
        #expect(F.days(logs) == [F.date(2026, 8, 15), F.date(2026, 9, 15), F.date(2026, 10, 15)])
        #expect(logs.first?.id == logId)
        #expect(logs.first?.date == F.date(2026, 8, 15, hour: 15), "Original log keeps its own date and time")
        #expect(logs.allSatisfy { $0.amount == 9.99 })
        #expect(schedule.startDate == F.date(2026, 8, 15))
        #expect(F.allLogs(in: context).count == 3)
    }

    @Test("Deleting the log a schedule was made from leaves the schedule running")
    func deleteSourceLogOfMadeSchedule() throws {
        let context = F.makeContext()
        let log = F.makeLog(in: context, date: F.date(2026, 10, 28))
        let schedule = RecurringEngine.makeSchedule(from: log, interval: .daily, in: context)
        try context.save()

        try F.deleteLog(log, in: context)
        F.generate(in: context, asOf: F.date(2026, 10, 30))

        #expect(F.days(F.logs(in: context, scheduleId: schedule.id)) == [F.date(2026, 10, 29), F.date(2026, 10, 30)])
    }
}
