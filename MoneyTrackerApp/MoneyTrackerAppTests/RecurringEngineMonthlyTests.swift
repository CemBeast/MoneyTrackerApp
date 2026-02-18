//
//  RecurringEngineMonthlyTests.swift
//  MoneyTrackerAppTests
//
//  Tests that monthly recurring transactions are automatically generated
//  when a month has passed since the template date.
//

import CoreData
import Foundation
import Testing
@testable import MoneyTrackerApp

@Suite("Monthly Recurring Transaction Generation")
struct RecurringEngineMonthlyTests {

    private func makeTestController() -> PersistenceController {
        PersistenceController.inMemoryForTesting()
    }

    private func createMonthlyTemplate(
        context: NSManagedObjectContext,
        date: Date,
        amount: Double = 1500.0,
        groupId: UUID? = nil
    ) -> CDTransaction {
        let template = CDTransaction(context: context)
        template.id = UUID()
        template.date = date
        template.amount = amount
        template.categoryRaw = MoneyCategory.housing.rawValue
        template.merchant = "Monthly Rent"
        template.paymentMethodRaw = PaymentMethod.debit.rawValue
        template.notes = "Recurring monthly"
        template.typeRaw = TransactionType.expense.rawValue
        template.isRecurring = true
        template.recurringIntervalRaw = RecurringInterval.monthly.rawValue
        template.recurringGroupId = groupId ?? UUID()
        template.generatedFromRecurringId = nil
        template.createdAt = Date()
        return template
    }

    private func countGeneratedInstances(
        context: NSManagedObjectContext,
        groupId: UUID
    ) -> Int {
        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "generatedFromRecurringId == %@", groupId as CVarArg)
        let results = (try? context.fetch(request)) ?? []
        return results.count
    }

    @Test("Monthly template from 1 month ago generates exactly 1 instance when due")
    func oneMonthAgoGeneratesOneInstance() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext
        let calendar = Calendar.current
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: Date())!

        let groupId = UUID()
        _ = createMonthlyTemplate(context: context, date: oneMonthAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let generated = countGeneratedInstances(context: context, groupId: groupId)
        #expect(generated == 1, "Expected 1 generated instance when template is 1 month old")
    }

    @Test("Monthly template from 3 months ago generates 3 instances")
    func threeMonthsAgoGeneratesThreeInstances() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext
        let calendar = Calendar.current
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date())!

        let groupId = UUID()
        _ = createMonthlyTemplate(context: context, date: threeMonthsAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let generated = countGeneratedInstances(context: context, groupId: groupId)
        #expect(generated == 3, "Expected 3 generated instances when template is 3 months old")
    }

    @Test("Monthly template from same month generates 0 instances")
    func sameMonthGeneratesNoInstances() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext
        let calendar = Calendar.current

        // Template on the 6th of current month, "now" on the 11th - same month, no full month has passed
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let templateDate = calendar.date(byAdding: .day, value: 5, to: startOfMonth)!   // 6th
        let asOfDate = calendar.date(byAdding: .day, value: 10, to: startOfMonth)!     // 11th

        let groupId = UUID()
        _ = createMonthlyTemplate(context: context, date: templateDate, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: asOfDate)

        let generated = countGeneratedInstances(context: context, groupId: groupId)
        #expect(generated == 0, "Expected 0 generated instances when template is in same month")
    }

    @Test("Calling generateDueTransactions twice does not create duplicates")
    func noDuplicatesOnSecondRun() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext
        let calendar = Calendar.current
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: Date())!

        let groupId = UUID()
        _ = createMonthlyTemplate(context: context, date: twoMonthsAgo, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())
        let firstRunCount = countGeneratedInstances(context: context, groupId: groupId)

        engine.generateDueTransactions(asOf: Date())
        let secondRunCount = countGeneratedInstances(context: context, groupId: groupId)

        #expect(firstRunCount == 2, "Expected 2 instances after first run (2 months)")
        #expect(secondRunCount == 2, "Expected no new instances on second run; got \(secondRunCount)")
    }

    @Test("Generated instance has correct amount and category from template")
    func generatedInstanceMatchesTemplate() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext
        let calendar = Calendar.current
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: Date())!

        let groupId = UUID()
        let amount: Double = 2100.50
        _ = createMonthlyTemplate(context: context, date: oneMonthAgo, amount: amount, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: Date())

        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "generatedFromRecurringId == %@", groupId as CVarArg)
        let instances = (try? context.fetch(request)) ?? []

        #expect(instances.count == 1)
        #expect(instances[0].amount == amount)
        #expect(instances[0].categoryRaw == MoneyCategory.housing.rawValue)
        #expect(instances[0].merchant == "Monthly Rent")
        #expect(instances[0].isRecurring == false, "Generated instances should not be recurring templates")
    }

    @Test("Monthly instance preserves day-of-month (or last day for shorter months)")
    func monthlyInstancePreservesDayOfMonth() throws {
        let controller = makeTestController()
        let context = controller.container.viewContext
        let calendar = Calendar.current

        // Template on the 15th of a month
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 9
        components.minute = 0
        let templateDate = calendar.date(from: components)!
        let feb2025 = calendar.date(from: DateComponents(year: 2025, month: 2, day: 15))!
        let asOfDate = calendar.date(byAdding: .day, value: 1, to: feb2025)!

        let groupId = UUID()
        _ = createMonthlyTemplate(context: context, date: templateDate, groupId: groupId)
        try context.save()

        let engine = RecurringEngine(context: context)
        engine.generateDueTransactions(asOf: asOfDate)

        let request = NSFetchRequest<CDTransaction>(entityName: "CDTransaction")
        request.predicate = NSPredicate(format: "generatedFromRecurringId == %@", groupId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDTransaction.date, ascending: true)]
        let instances = (try? context.fetch(request)) ?? []

        #expect(instances.count == 1)
        let instanceDay = calendar.component(.day, from: instances[0].date)
        let instanceMonth = calendar.component(.month, from: instances[0].date)
        #expect(instanceMonth == 2, "Instance should be in February")
        #expect(instanceDay == 15, "Instance should be on the 15th to match template")
    }
}
