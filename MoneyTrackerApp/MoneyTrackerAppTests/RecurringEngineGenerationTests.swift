//
//  RecurringEngineGenerationTests.swift
//  MoneyTrackerAppTests
//
//  Occurrence generation from schedules: first occurrence on the start date, start-of-day due,
//  back-dated catch-up, month-end clamping, and no duplicates.
//

import CoreData
import Foundation
import Testing
@testable import MoneyTrackerApp

@Suite("Recurring generation")
@MainActor // viewContext is main-queue bound; Swift Testing would otherwise run these on background threads
struct RecurringEngineGenerationTests {
    private typealias F = RecurringFixtures

    // MARK: Daily

    @Test("Back-dated daily schedule logs every day from the start date through today")
    func backdatedDailyCatchesUp() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .daily, start: F.date(2026, 10, 28))

        F.generate(in: context, asOf: F.date(2026, 10, 30, hour: 8))

        #expect(F.days(F.logs(in: context, scheduleId: schedule.id)) == [
            F.date(2026, 10, 28), F.date(2026, 10, 29), F.date(2026, 10, 30)
        ])
    }

    @Test("An occurrence is due at the start of its day, not at a time of day")
    func dueAtStartOfDay() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .daily, start: F.date(2026, 10, 30, hour: 21))

        F.generate(in: context, asOf: F.date(2026, 10, 30))

        #expect(F.logs(in: context, scheduleId: schedule.id).count == 1)
    }

    @Test("A future start date logs nothing yet")
    func futureStartLogsNothing() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .daily, start: F.date(2026, 11, 5))

        F.generate(in: context, asOf: F.date(2026, 10, 30))

        #expect(F.logs(in: context, scheduleId: schedule.id).isEmpty)
    }

    @Test("Running generation repeatedly creates no duplicates")
    func idempotent() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .daily, start: F.date(2026, 10, 20))
        let now = F.date(2026, 10, 30, hour: 12)

        F.generate(in: context, asOf: now)
        F.generate(in: context, asOf: now)
        F.generate(in: context, asOf: now)

        #expect(F.logs(in: context, scheduleId: schedule.id).count == 11)
    }

    @Test("Generated logs copy the schedule's details and record their scheduled date")
    func generatedLogMatchesSchedule() throws {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .monthly, start: F.date(2026, 10, 5), amount: 11.99)

        F.generate(in: context, asOf: F.date(2026, 10, 5))

        let log = try #require(F.logs(in: context, scheduleId: schedule.id).first)
        #expect(log.amount == 11.99)
        #expect(log.originalAmount == 11.99)
        #expect(log.originalCurrencyRaw == AppCurrency.usd.rawValue)
        #expect(log.categoryRaw == schedule.categoryRaw)
        #expect(log.merchant == "Spotify")
        #expect(log.paymentMethodRaw == schedule.paymentMethodRaw)
        #expect(log.typeRaw == schedule.typeRaw)
        #expect(log.recurringInterval == .monthly)
        #expect(log.occurrenceDate == F.date(2026, 10, 5))
        #expect(log.isRecurring == false)
    }

    // MARK: Weekly

    @Test("Weekly schedule logs every 7 days from the start date")
    func weeklyEverySevenDays() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .weekly, start: F.date(2026, 10, 7))

        F.generate(in: context, asOf: F.date(2026, 10, 30))

        #expect(F.days(F.logs(in: context, scheduleId: schedule.id)) == [
            F.date(2026, 10, 7), F.date(2026, 10, 14), F.date(2026, 10, 21), F.date(2026, 10, 28)
        ])
    }

    @Test("Weekly schedule doesn't log before a full week has passed")
    func weeklyNotDueEarly() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .weekly, start: F.date(2026, 10, 24))

        F.generate(in: context, asOf: F.date(2026, 10, 30, hour: 23))

        #expect(F.logs(in: context, scheduleId: schedule.id).count == 1)
    }

    // MARK: Monthly

    @Test("Monthly schedule on the 31st clamps to the last day of shorter months")
    func monthlyClampsMonthEnd() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .monthly, start: F.date(2026, 1, 31))

        F.generate(in: context, asOf: F.date(2026, 5, 15))

        #expect(F.days(F.logs(in: context, scheduleId: schedule.id)) == [
            F.date(2026, 1, 31), F.date(2026, 2, 28), F.date(2026, 3, 31), F.date(2026, 4, 30)
        ])
    }

    @Test("Monthly schedule lands on Feb 29 in a leap year")
    func monthlyLeapYear() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .monthly, start: F.date(2028, 1, 31))

        F.generate(in: context, asOf: F.date(2028, 3, 1))

        #expect(F.days(F.logs(in: context, scheduleId: schedule.id)) == [
            F.date(2028, 1, 31), F.date(2028, 2, 29)
        ])
    }

    @Test("Monthly schedule spanning a year boundary")
    func monthlyAcrossYearEnd() {
        let context = F.makeContext()
        let schedule = F.makeSchedule(in: context, interval: .monthly, start: F.date(2026, 11, 15))

        F.generate(in: context, asOf: F.date(2027, 2, 15))

        #expect(F.days(F.logs(in: context, scheduleId: schedule.id)) == [
            F.date(2026, 11, 15), F.date(2026, 12, 15), F.date(2027, 1, 15), F.date(2027, 2, 15)
        ])
    }

    @Test("Multiple schedules generate independently")
    func independentSchedules() {
        let context = F.makeContext()
        let spotify = F.makeSchedule(in: context, interval: .monthly, start: F.date(2026, 9, 1))
        let coffee = F.makeSchedule(in: context, interval: .daily, start: F.date(2026, 10, 28), merchant: "Coffee")

        F.generate(in: context, asOf: F.date(2026, 10, 30))

        #expect(F.logs(in: context, scheduleId: spotify.id).count == 2)
        #expect(F.logs(in: context, scheduleId: coffee.id).count == 3)
    }
}
