## MoneyTrackerApp

Cyberpunk-flavored personal finance tracker built with SwiftUI and Core Data. Log expenses and income, set per-category budgets, view insights with charts, and speed up entry with presets and recurring items.

### Features
- Transactions: add/edit expenses, incomes, and transfers with category, payment method, merchant, notes, and date.
- Budgets: set monthly limits per category; progress bars and over-budget states are highlighted.
- Insights: category distribution pie, payment-method pie, last-6-months bar chart, monthly averages, and percentage breakdowns (Charts framework; iOS 16+).
- Categories: unique neon color per `MoneyCategory` (see `Theme/MoneyCategory+Color.swift`) plus icons and labels.
- Presets: quick-add common transactions from saved presets.
- Recurring: `RecurringEngine` generates transactions for the current month.
- Core Data: local persistence via `PersistenceController`.

### Requirements
- Xcode 15+ (Swift 5.9+)
- iOS 16+ target (Charts usage)

### Getting Started
1) Open `MoneyTrackerApp.xcodeproj` in Xcode.  
2) Select an iOS 16+ simulator or device.  
3) Run the `MoneyTrackerApp` scheme.

### Project Structure
- `MoneyTrackerApp/`
  - `MoneyTrackerAppApp.swift` / `ContentView.swift`: entry and root tabs.
  - `Core/`: Core Data stack, models, app bootstrap.
  - `Components/`: reusable UI pieces (transaction rows, pickers, etc.).
  - `Features/`: feature-specific screens (budgets, presets).
  - `Views/`: primary screens (Months, Log, Insights, Categories, detail views).
  - `Theme/`: colors, helpers, category color mapping.
  - `Utilities/`: analytics (`InsightsStats`) and recurring generation.
- `MoneyTrackerAppTests/`, `MoneyTrackerAppUITests/`: placeholders for unit/UI tests.

### Data Model
- Categories: defined in `Core/Models.swift` as `MoneyCategory` and colored via `Theme/MoneyCategory+Color.swift`.
- Payment methods and transaction types also live in `Models.swift`.
- Persistence: `PersistenceController` uses `MoneyTracker` Core Data model (`CoreDataEntities.swift`).

### Color System
- Each category has a dedicated neon color (no duplicates). When adding a new category, update both `MoneyCategory` in `Models.swift` and its color mapping in `Theme/MoneyCategory+Color.swift`.

### Development Notes
- Charts require iOS 16+. Fallback text is shown on older OS versions.
- Budgets and insights iterate over `MoneyCategory.allCases`; add new cases carefully to keep UI consistent.
- Recurring generation is triggered from the Months view toolbar.
- Quick-add presets live in `Features/PresetsQuickAddSheet.swift`.

### Running Tests
- In Xcode: `Product > Test` (targets: `MoneyTrackerAppTests`, `MoneyTrackerAppUITests`).

### Troubleshooting
- If charts are blank, ensure you’re running on iOS 16+.
- If data seems missing, confirm the correct simulator/device and that the Core Data store wasn’t reset.
