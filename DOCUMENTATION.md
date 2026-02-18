# MoneyTrackerApp — Codebase Documentation

This document provides in-depth documentation for the MoneyTrackerApp codebase. It is written for developers unfamiliar with the project—including sophomore-level computer science students—and explains every significant struct, class, function, enum, and extension.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Core Layer](#2-core-layer)
3. [Theme Layer](#3-theme-layer)
4. [Components](#4-components)
5. [Views](#5-views)
6. [Features](#6-features)
7. [Utilities](#7-utilities)
8. [Data Flow Glossary](#8-data-flow-glossary)

---

## 1. Architecture Overview

### What is MoneyTrackerApp?

A **cyberpunk-styled personal finance tracker** for iOS that lets users:
- Log expenses, income, and transfers
- Set monthly budgets per spending category
- View insights (charts, averages, percentages)
- Quick-add transactions from presets
- Auto-generate recurring transactions (e.g., rent, subscriptions)

### Technology Stack

- **SwiftUI** — UI framework
- **Core Data** — local persistence (no `.xcdatamodeld` file; model is built in code)
- **Charts** — Apple’s Charts framework (iOS 16+)
- **UIKit** — used for tab bar and navigation bar theming

### App Entry Point

The app uses `@main` in **MoneyTrackApp.swift** (not `MoneyTrackerAppApp.swift`). The main `WindowGroup` shows `RootTabView` and injects the Core Data `managedObjectContext` via `@Environment(\.managedObjectContext)`.

---

## 2. Core Layer

### 2.1 Models.swift

Defines domain models used across the app (enums, structs, and extensions).

#### Enums

---

**`MoneyCategory: String, CaseIterable, Identifiable`**

Spending categories for transactions.

| Case | Raw Value | Description |
|------|-----------|-------------|
| `housing` | "Housing" | Rent, mortgage |
| `fixedBills` | "Fixed Bills" | Utilities, insurance |
| `food` | "Food" | Groceries, dining |
| `transportation` | "Transportation" | Gas, transit |
| `healthcare` | "Healthcare" | Medical expenses |
| `funLifestyle` | "Fun/Lifestyle" | Entertainment |
| `shopping` | "Shopping" | General purchases |
| `subscriptions` | "Subscriptions" | Streaming, apps |
| `savings` | "Savings" | Savings contributions |
| `investing` | "Investing" | Investments |
| `travel` | "Travel" | Travel expenses |
| `gifts` | "Gifts" | Gifts and donations |
| `misc` | "Misc" | Uncategorized |

- **`id: String`** — Same as `rawValue` (used for `ForEach` and `Identifiable`).
- **`allCases`** — All categories (from `CaseIterable`).

---

**`PaymentMethod: String, CaseIterable, Identifiable`**

How the user paid for a transaction.

| Case | Raw Value |
|------|-----------|
| `cash` | "Cash" |
| `debit` | "Debit" |
| `credit` | "Credit" |
| `applePay` | "Apple Pay" |
| `venmo` | "Venmo" |
| `other` | "Other" |

---

**`TransactionType: Int16, CaseIterable, Identifiable`**

Kind of transaction. Stored in Core Data as `Int16`.

| Case | Raw Value | Label |
|------|-----------|-------|
| `expense` | 0 | "Expense" |
| `income` | 1 | "Income" |
| `transfer` | 2 | "Transfer" |

- **`label: String`** — Human-readable label for the type.

---

**`RecurringInterval: String, CaseIterable, Identifiable`**

Recurrence interval for recurring transactions.

| Case | Raw Value |
|------|-----------|
| `monthly` | "monthly" |
| `weekly` | "weekly" |
| `daily` | "daily" |

---

#### Structs

**`MonthKey: Hashable, Comparable`**

Identifies a calendar month for grouping transactions and budgets.

- **Properties**
  - `year: Int`
  - `month: Int`

- **Static function `<(lhs:rhs:) -> Bool`**  
  Compares two `MonthKey`s chronologically (year first, then month).

- **Computed property `startDate: Date`**  
  Returns the first day of that month at midnight.

- **Computed property `title: String`**  
  Formatted string like `"January 2025"`.

---

#### Extensions

**`Date.monthKey() -> MonthKey`**

- **Returns:** The `MonthKey` for the month containing this date.
- **Use case:** Grouping transactions by month.

---

**`Date.startOfMonth() -> Date`**

- **Returns:** The first day of the month for this date.
- **Use case:** Budget start dates, month range queries.

---

**`Double.currency() -> String`**

- **Returns:** Locale-aware currency string (e.g., `"$42.50"`).
- **Use case:** Displaying amounts in the UI.

---

### 2.2 CoreDataEntities.swift

Defines Core Data entity classes and their properties. These map to the in-code schema in `PersistenceController.makeModel()`.

#### CDTransaction

Core Data entity for a single transaction.

**Raw (persisted) properties:**

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `date` | `Date` | Transaction date |
| `amount` | `Double` | Transaction amount |
| `categoryRaw` | `String` | Category raw value |
| `merchant` | `String?` | Optional merchant name |
| `paymentMethodRaw` | `String?` | Optional payment method |
| `notes` | `String?` | Optional notes |
| `typeRaw` | `Int16` | Transaction type (0/1/2) |
| `isRecurring` | `Bool` | Whether it is a recurring template |
| `recurringIntervalRaw` | `String?` | "monthly"/"weekly"/"daily" |
| `recurringGroupId` | `UUID?` | Groups template with generated instances |
| `generatedFromRecurringId` | `UUID?` | Non-nil if generated from a recurring template |
| `createdAt` | `Date` | Creation timestamp |

**Computed (convenience) properties:**

- `category: MoneyCategory` — From `categoryRaw`; default `.misc`.
- `paymentMethod: PaymentMethod` — From `paymentMethodRaw`; default `.other`.
- `type: TransactionType` — From `typeRaw`; default `.expense`.
- `recurringInterval: RecurringInterval?` — From `recurringIntervalRaw`.

**Static function `fetchRequest() -> NSFetchRequest<CDTransaction>`**  
Returns a fetch request for the `CDTransaction` entity.

---

#### CDPreset

Core Data entity for a quick-add preset.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `name` | `String` | Preset name |
| `defaultCategoryRaw` | `String` | Default category |
| `defaultMerchant` | `String?` | Default merchant |
| `defaultPaymentMethodRaw` | `String?` | Default payment method |
| `defaultNotes` | `String?` | Default notes |
| `defaultAmount` | `Double` | Default amount (0 = prompt user) |

**Computed properties:** `defaultCategory`, `defaultPaymentMethod`.

---

#### CDBudget

Core Data entity for a monthly budget limit per category.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `monthStart` | `Date` | First day of the budget month |
| `categoryRaw` | `String` | Category |
| `limit` | `Double` | Budget limit |

**Computed property:** `category: MoneyCategory`.

---

### 2.3 PersistenceController.swift

Manages the Core Data stack and in-memory mode.

#### PersistenceController

**Type:** `final class` (singleton)

**Properties:**
- `static let shared: PersistenceController` — Singleton instance.
- `container: NSPersistentContainer` — Core Data container.

**Initializer `init(inMemory: Bool = false)`**

- **Parameters:**
  - `inMemory`: If `true`, uses `/dev/null` for the store (no persistence).
- **Behavior:**
  - Builds model via `makeModel()`.
  - Creates `NSPersistentContainer` named `"MoneyTrack"`.
  - Loads persistent stores.
  - Sets merge policy and `automaticallyMergesChangesFromParent` on `viewContext`.

**Function `save(_ context: NSManagedObjectContext)`**

- **Parameters:** `context` — The Core Data context to save.
- **Returns:** Nothing.
- **Use case:** Persist changes after add/edit/delete.
- **Behavior:**
  - Does nothing if `context.hasChanges` is false.
  - Obtains permanent IDs for newly inserted objects.
  - Calls `context.save()`.
  - If saving a child context, merges to view context.
  - Crashes on save error.

**Private function `makeModel() -> NSManagedObjectModel`**

- **Returns:** A Core Data model with entities `CDTransaction`, `CDPreset`, `CDBudget` and their attributes.
- **Use case:** Used in `init` to define the schema when no `.xcdatamodeld` file is used.

**Private function `attr(_ name: String, _ type: NSAttributeType, optional: Bool) -> NSAttributeDescription`**

- **Parameters:**
  - `name`: Attribute name.
  - `type`: Core Data attribute type.
  - `optional`: Whether the attribute is optional.
- **Returns:** Configured `NSAttributeDescription`.
- **Use case:** Helper for building the model in `makeModel()`.

---

### 2.4 MoneyTrackApp.swift

Main app entry point and lifecycle handling.

#### MoneyTrackApp

**Type:** `struct` conforming to `App`

**Property:** `@main` — Marks this as the app entry point.

**Properties:**
- `@Environment(\.scenePhase) private var scenePhase`
- `let persistence = PersistenceController.shared`

**Body:**
- `WindowGroup` containing `RootTabView`.
- Injects `managedObjectContext` via `.environment(\.managedObjectContext, ...)`.
- On appear and when scene becomes active, calls `generateDueRecurringTransactions()`.

**Private function `generateDueRecurringTransactions()`**

- **Returns:** Nothing.
- **Use case:** Create recurring instances when the app launches or returns to foreground.
- **Behavior:** Creates a `RecurringEngine` and calls `generateDueTransactions()`.

---

### 2.5 MoneyTrackerAppApp.swift

Alternative app struct (without `@main`). Currently unused; `@main` is in `MoneyTrackApp.swift`. Shows `ContentView` (a simple placeholder).

---

### 2.6 ContentView.swift

Placeholder view: globe icon and "Hello, world!". Not used in the main app flow.

---

## 3. Theme Layer

### 3.1 Theme.swift

Cyberpunk-themed colors, modifiers, and UI components.

#### Color Extensions

| Color | Use |
|-------|-----|
| `cyberBlack` | Main background |
| `cyberDarkGray` | Card backgrounds |
| `cyberGray` | Secondary surfaces |
| `cyberLightGray` | Light accents |
| `neonGreen` | Primary accent, selected state |
| `neonGreenDim` | Dimmed green |
| `neonGreenGlow` | Glow effects |
| `neonPink`, `neonBlue`, `neonPurple`, etc. | Category/payment accents |
| `neonRed` | Over-budget, errors |
| `cyberChartColors` | Array of chart colors |

---

#### ViewModifiers

**`CyberCard: ViewModifier`**

- **Parameters:** `glowColor`, `showGlow`
- **Effect:** Dark card with rounded corners, stroke, optional glow.
- **Usage:** `.cyberCard(glowColor: .neonGreen)` on any `View`.

**`CyberNavTitle: ViewModifier`**

- **Parameters:** `title: String`
- **Effect:** Navigation title, dark toolbar, neon green styling.
- **Usage:** `.cyberNavTitle("My Screen")`.

---

#### ButtonStyles

- **`CyberButtonStyle`** — Primary button (filled green).
- **`CyberSmallButtonStyle`** — Small caption-style button.
- **`CyberIconButtonStyle`** — Circular icon button.

---

#### Components

**`CyberProgressBar`**

- **Parameters:** `progress: Double`, `barColor`, `isOverBudget`
- **Use case:** Budget progress, category distribution.
- **Behavior:** Horizontal bar; red gradient when over budget.

**`CyberTag`**

- **Parameters:** `text: String`, `color: Color`
- **Use case:** Category/payment labels in transaction rows.

**`CyberStat`** — Title + value display.

**`CyberSectionHeader`** — Section title with green accent bar.

**`CyberDivider`** — Horizontal divider with gradient.

**`GlowText`** — Text with glow shadow.

**`CyberListRow`** — List row background modifier.

---

### 3.2 MoneyCategory+Color.swift

Adds a `color` property to `MoneyCategory`.

**`MoneyCategory.color: Color`** — Each category maps to a unique neon color (see `Theme.swift` for palette).

---

### 3.3 UIHelpers.swift

Toast and other UI utilities.

#### Toast

**`Toast: View`**

- **Parameters:** `text`, optional `actionTitle`, optional `action`
- **Use case:** Simple toast with optional action button.

**View extension `toast(isPresented:content:)`**

- **Parameters:**
  - `isPresented: Binding<Bool>`
  - `content`: Closure returning the toast view.
- **Returns:** Modified view with toast overlay.
- **Use case:** Show toasts (e.g., "Transaction deleted", "Undo").
- **Behavior:** Toast appears at bottom, auto-dismisses after 3 seconds.

---

#### Other Components

**`CyberEmptyState`** — Icon, title, subtitle, optional button for empty lists.

**`CyberLoadingIndicator`** — Spinning circle loader.

**`CyberAmountInput`** — Dollar-sign + text field for amount input.

---

## 4. Components

### 4.1 AddEditTransactionView.swift

Form for creating or editing a transaction.

#### AddEditTransactionView

**Type:** `struct` conforming to `View`

**Initializer `init(transaction:preset:onSaved:)`**

- **Parameters:**
  - `transaction: CDTransaction?` — If present, edit mode.
  - `preset: CDPreset?` — If present, prefill from preset.
  - `onSaved: (() -> Void)?` — Callback after save.
- **Behavior:** Initializes `@State` from `transaction`, `preset`, or defaults.

**Private function `save()`**

- **Returns:** Nothing.
- **Use case:** Validate, update or create `CDTransaction`, persist, dismiss.
- **Behavior:**
  - Validates amount > 0.
  - Creates or updates transaction.
  - Sets recurring fields (e.g., `recurringGroupId`, `generatedFromRecurringId`).
  - Calls `PersistenceController.shared.save(context)`.
  - Calls `onSaved?()` and `dismiss()`.

---

#### CyberFormRow

**Parameters:** `label: String`, `@ViewBuilder content`
**Use case:** Label + content in form rows (e.g., "Date" + `DatePicker`).

---

### 4.2 TransactionQueryList.swift

Displays a filtered list of transactions.

#### TransactionQueryList

**Initializer**

- **Parameters:**
  - `searchText: String` — Filter by merchant/notes (CONTAINS).
  - `category: MoneyCategory?` — Filter by category.
  - `paymentMethod: PaymentMethod?` — Filter by payment method.
  - `month: MonthKey?` — Filter by month.
  - `onTap: (CDTransaction) -> Void` — Called when a row is tapped.
  - `onDelete: ((CDTransaction) -> Void)?` — Optional delete callback.
- **Behavior:** Builds `NSPredicate`s, creates `FetchRequest`, sorts by date descending.

**Use case:** Log view, category detail, month detail.

---

#### CyberTransactionRow

**Parameters:** `transaction: CDTransaction`
**Use case:** Single transaction row (icon, merchant, category, amount, date).

---

### 4.3 MonthPickerMenu.swift

#### MonthPickerMenu

**Parameters:**
- `selectedMonth: Binding<MonthKey?>`
- `availableMonths: [MonthKey]`

**Use case:** Month filter dropdown ("All Months" or specific month).

---

## 5. Views

### 5.1 RootTabView.swift

#### RootTabView

**Tabs:**
1. **Log** — `LogView`
2. **Months** — `MonthsView`
3. **Categories** — `CategoriesView`
4. **Insights** — `InsightsView`

**`init()`:** Configures `UITabBar` and `UINavigationBar` with cyberpunk styling (dark background, neon green accents).

---

### 5.2 LogView.swift

Main transaction log with search and filters.

**State:**
- `searchText`, `selectedCategory`, `selectedPaymentMethod`, `selectedMonth`
- `showAddTransaction`, `showQuickAdd`, `transactionToEdit`, `deletedTransaction`, `showUndoToast`, `refreshToken`

**Sheets:** Add transaction, Quick Add (presets), Edit transaction, Undo toast.

**Functionality:**
- Search by merchant/notes.
- Filter by month, category, payment method.
- Delete with undo toast.
- Opens `AddEditTransactionView` or `PresetsQuickAddSheet`.

---

**`CyberSearchBar`** — Search field with clear button.

**`CyberFilterButton`** — Filter pill with dropdown.

**`CyberToast`** — Toast with optional action (e.g., "Undo").

---

### 5.3 MonthsView.swift

List of months that have transactions, with totals.

**Computed:**
- `transactionSignature` — String based on transaction IDs/amounts/dates; used to force UI refresh.
- `availableMonths` — `[MonthKey]` from transactions, sorted newest first.

---

**`CyberMonthRow`**

**Parameters:** `month: MonthKey`, `transactions: FetchedResults<CDTransaction>`
**Use case:** Row showing month name, transaction count, total spent.
**Computed:** `monthTransactions`, `total` (expenses only), `transactionCount`.

---

**`MonthDetailView`**

**Parameters:** `month: MonthKey`

**Computed:** `monthTransactions`, `totalSpent`, `categoryTotals`, `budgetMap`.

**Toolbar:** Recurring generation button, Budgets sheet.

**Use case:** Month summary with category breakdown, budgets, and transaction list.

---

**`CyberCategoryBudgetRow`**

**Parameters:** `category`, `spent`, `budget?`
**Use case:** Category row with progress bar and over-budget state.

---

### 5.4 CategoriesView.swift

Overview of spending by category.

**Computed:** `categoryTotals`, `grandTotal`, `categoryIcon(_:)`
**Use case:** Grid of category cards; tap navigates to `CategoryDetailView`.

---

**`CyberCategoryCard`**

**Parameters:** `category`, `total`, `percent`, `color`, `icon`
**Use case:** Category card with total and percentage.

---

### 5.5 CategoryDetailView.swift

Transactions for a single category, with month filter.

**Parameters:** `category: MoneyCategory`

**Computed:** `availableMonths`, `categoryTransactions`, `total`, `categoryColor`, `categoryIcon`

**Use case:** Drill-down into one category with "All Time" or per-month filter.

---

**`CyberFilterPill`**

**Parameters:** `title`, `isSelected`, `action`
**Use case:** "All Time" vs month filter pills.

---

### 5.6 InsightsView.swift

Charts and statistics.

**Computed:** `availableMonths`, `transactionSignature`, `stats` (from `InsightsStats`)

**Subviews:**
- `CyberStatCard` — Single stat (e.g., average monthly spending).
- `CyberCategoryAveragesView` — Monthly averages per category.
- `CyberPercentagesView` — Category percentage distribution with progress bars.
- `CyberChartsView`:
  - `CyberLast6MonthsChart` — Bar chart of last 6 months.
  - `CyberCategoryPieChart` — Category pie chart.
  - `CyberPaymentMethodPieChart` — Payment method pie chart.

**Month filter:** Toolbar menu to filter insights by month or "All Time".

---

## 6. Features

### 6.1 BudgetsView.swift

Sheet for setting monthly budgets per category.

**Parameters:** `monthStart: Date`

**Functions:**
- **`loadBudgets()`** — Loads existing budgets into `budgetLimits`.
- **`save()`** — Deletes existing budgets for the month, creates new ones from `budgetLimits`, saves, dismisses.

---

**`CyberBudgetInputRow`**

**Parameters:** `category`, `color`, `value: Binding<String>`
**Use case:** Category + dollar amount input row.

---

### 6.2 PresetsQuickAddSheet.swift

Quick-add sheet for presets.

**State:** `showAddPreset`, `showAddTransaction`, `selectedPreset`, `presetToEdit`, `toastMessage`

**Functions:**
- **`deletePreset(_ preset: CDPreset)`** — Deletes preset and saves.
- **`handlePresetTap(_ preset:)`** — If preset has amount, creates transaction immediately; otherwise opens add form.
- **`createTransaction(from preset:)`** — Creates a new `CDTransaction` from preset and saves.

---

**`CyberPresetRow`**

**Parameters:** `preset`, `onTap`
**Use case:** Preset row with name, category, merchant, amount.

---

**`CyberAddPresetView`**

**Parameters:** `preset: CDPreset?` — Nil = create, non-nil = edit (note: current `save()` always creates; potential bug).

**Function `save()`** — Creates new `CDPreset` from form, saves, dismisses.

---

## 7. Utilities

### 7.1 RecurringEngine.swift

Generates recurring transaction instances from recurring templates.

#### RecurringEngine

**Properties:** `context: NSManagedObjectContext`, `calendar: Calendar`

**Function `generateForMonth(_ month: MonthKey)`**

- **Parameters:** `month` — Month to generate for.
- **Returns:** Nothing.
- **Use case:** Manually trigger generation for a specific month (e.g., from Month detail toolbar).
- **Behavior:** Fetches recurring templates, generates instances for the month if due, saves.

---

**Function `generateDueTransactions(asOf now: Date = Date())`**

- **Parameters:** `now` — Cutoff date (default: today).
- **Returns:** Nothing.
- **Use case:** Called on app launch and when app becomes active.
- **Behavior:** For **monthly** templates, generates instances from first month after template up to `now`. For **weekly** templates, generates instances for each full week since the template date up to `now`. For **daily** templates, generates instances for each full day since the template date up to `now`. Skips already-generated periods.

---

**Private functions:**

- **`fetchRecurringTemplates() -> [CDTransaction]?`** — Fetches transactions where `isRecurring == YES` and `generatedFromRecurringId == nil`.
- **`generateMonthlyInstanceIfNeeded(for:month:onlyIfDueBy:)`** — Creates one instance for a month if not yet generated and within `onlyIfDueBy`.
- **`hasGeneratedInstance(groupId:month:) -> Bool`** — Checks if an instance for that group/month already exists.
- **`monthlyOccurrenceDate(for:in:) -> Date`** — Maps template date to same day in target month (handles shorter months).
- **`nextMonth(after:) -> MonthKey`** — Returns the next calendar month.
- **`generateWeeklyInstancesIfNeeded(for:onlyIfDueBy:)`** — Creates instances for each full week since template.
- **`hasGeneratedInstanceForWeek(groupId:occurrenceDate:) -> Bool`** — Checks if an instance exists for that week.
- **`addWeeks(_:to:) -> Date`** — Adds N weeks to a date.
- **`generateDailyInstancesIfNeeded(for:onlyIfDueBy:)`** — Creates instances for each full day since template.
- **`hasGeneratedInstanceForDay(groupId:occurrenceDate:) -> Bool`** — Checks if an instance exists for that day.
- **`addDays(_:to:) -> Date`** — Adds N days to a date.

---

### 7.2 InsightsStats.swift

Computes statistics for the Insights view.

#### InsightsStats

**Property:** `context: NSManagedObjectContext`

**Functions:**

| Function | Returns | Description |
|----------|---------|-------------|
| `allTimeTotalsPerCategory()` | `[MoneyCategory: Double]` | Total spent per category, all time |
| `monthlyTotals()` | `[MonthKey: Double]` | Total spent per month |
| `averagePerMonthOverall()` | `Double` | Average monthly spending |
| `averagePerMonthPerCategory()` | `[MoneyCategory: Double]` | Average per category per month |
| `percentPerCategoryOverall()` | `[MoneyCategory: Double]` | Category percentages, all time |
| `percentPerCategoryForMonth(_:)` | `[MoneyCategory: Double]` | Category percentages for a month |
| `allTimeTotalsPerPaymentMethod()` | `[PaymentMethod: Double]` | Totals by payment method |
| `percentPerPaymentMethodOverall()` | `[PaymentMethod: Double]` | Payment method percentages |
| `percentPerPaymentMethodForMonth(_:)` | `[PaymentMethod: Double]` | Payment method percentages for a month |

All expense-only; uses `typeRaw == TransactionType.expense.rawValue`.

---

## 8. Data Flow Glossary

| Term | Meaning |
|------|---------|
| **Managed Object Context** | Core Data workspace; changes are saved with `PersistenceController.shared.save(context)` |
| **FetchRequest** | SwiftUI property wrapper that fetches Core Data entities and refreshes the view when data changes |
| **Recurring template** | Transaction with `isRecurring == true` and `generatedFromRecurringId == nil` |
| **Generated instance** | Transaction created by `RecurringEngine`; `generatedFromRecurringId == recurringGroupId` |
| **Recurring group** | Set of template + instances sharing the same `recurringGroupId` |
| **MonthKey** | Year + month used to group transactions and budgets |
| **transactionSignature** | String derived from transaction data; used as `.id()` to force SwiftUI to refresh when data changes |

---

## Quick Reference: Where Things Live

| Feature | Primary File(s) |
|---------|-----------------|
| App entry, recurring on launch | `MoneyTrackApp.swift` |
| Domain models | `Models.swift` |
| Core Data entities | `CoreDataEntities.swift` |
| Persistence | `PersistenceController.swift` |
| Colors, card styles, buttons | `Theme.swift`, `MoneyCategory+Color.swift` |
| Toast, empty state | `UIHelpers.swift` |
| Add/Edit transaction | `AddEditTransactionView.swift` |
| Transaction list | `TransactionQueryList.swift` |
| Log screen | `LogView.swift` |
| Months overview | `MonthsView.swift` |
| Categories overview | `CategoriesView.swift` |
| Category detail | `CategoryDetailView.swift` |
| Insights & charts | `InsightsView.swift`, `InsightsStats.swift` |
| Budgets | `BudgetsView.swift` |
| Presets | `PresetsQuickAddSheet.swift` |
| Recurring generation | `RecurringEngine.swift` |
