import CoreData

final class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "MoneyTrack", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("CoreData error: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func save(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            // Obtain permanent IDs for new objects before saving
            if !context.insertedObjects.isEmpty {
                try context.obtainPermanentIDs(for: Array(context.insertedObjects))
            }
            
            // Save the context - this will trigger CoreData change notifications
            try context.save()
            
            // If saving a child context, merge changes to view context
            if context != container.viewContext && context.parent == container.viewContext {
                container.viewContext.perform {
                    try? self.container.viewContext.save()
                }
            }
        }
        catch {
            let err = error as NSError
            fatalError("CoreData save error: \(err), \(err.userInfo)")
        }
    }

    // MARK: - Code-first model
    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Transaction
        let txn = NSEntityDescription()
        txn.name = "CDTransaction"
        txn.managedObjectClassName = "CDTransaction"

        // Preset
        let preset = NSEntityDescription()
        preset.name = "CDPreset"
        preset.managedObjectClassName = "CDPreset"

        // Budget
        let budget = NSEntityDescription()
        budget.name = "CDBudget"
        budget.managedObjectClassName = "CDBudget"

        txn.properties = [
            attr("id", .UUIDAttributeType, optional: false),
            attr("date", .dateAttributeType, optional: false),
            attr("amount", .doubleAttributeType, optional: false),
            attr("categoryRaw", .stringAttributeType, optional: false),
            attr("merchant", .stringAttributeType, optional: true),
            attr("paymentMethodRaw", .stringAttributeType, optional: true),
            attr("notes", .stringAttributeType, optional: true),
            // 0=expense, 1=income, 2=transfer (UI can focus on expense)
            attr("typeRaw", .integer16AttributeType, optional: false),

            // Recurring (templates)
            attr("isRecurring", .booleanAttributeType, optional: false),
            attr("recurringIntervalRaw", .stringAttributeType, optional: true), // "monthly" | "weekly" | "daily"
            attr("recurringGroupId", .UUIDAttributeType, optional: true),
            attr("generatedFromRecurringId", .UUIDAttributeType, optional: true),

            attr("createdAt", .dateAttributeType, optional: false)
        ]

        preset.properties = [
            attr("id", .UUIDAttributeType, optional: false),
            attr("name", .stringAttributeType, optional: false),
            attr("defaultCategoryRaw", .stringAttributeType, optional: false),
            attr("defaultMerchant", .stringAttributeType, optional: true),
            attr("defaultPaymentMethodRaw", .stringAttributeType, optional: true),
            attr("defaultNotes", .stringAttributeType, optional: true),
            attr("defaultAmount", .doubleAttributeType, optional: true)
        ]

        budget.properties = [
            attr("id", .UUIDAttributeType, optional: false),
            attr("monthStart", .dateAttributeType, optional: false), // first day of month
            attr("categoryRaw", .stringAttributeType, optional: false),
            attr("limit", .doubleAttributeType, optional: false)
        ]

        model.entities = [txn, preset, budget]
        return model
    }

    private static func attr(_ name: String, _ type: NSAttributeType, optional: Bool) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = optional
        return a
    }
}

