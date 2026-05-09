//
//  CurrencyViewModel.swift
//  MoneyTrackerApp
//
//  Handles selected currency and conversion. Amounts are stored in base currency (USD).
//  Rates are fetched from the API once per day; manual rates used as fallback.
//

import Foundation
import SwiftUI
import Combine

/// Base currency for stored amounts. All amounts in the app are in USD.
private let baseCurrency = AppCurrency.usd

/// Minimum interval between API fetches (once per day).
private let fetchInterval: TimeInterval = 24 * 60 * 60

final class CurrencyViewModel: ObservableObject {
    private let userDefaultsKey = "MoneyTracker.selectedCurrency"
    private let lastRatesFetchKey = "MoneyTracker.lastRatesFetchDate"
    private let cachedRatesKey = "MoneyTracker.cachedRates"

    /// Currently selected display currency.
    @Published var selectedCurrency: AppCurrency {
        didSet {
            UserDefaults.standard.set(selectedCurrency.rawValue, forKey: userDefaultsKey)
        }
    }

    /// Conversion rates from base (USD) to each currency. Filled from API when available; otherwise manual fallback.
    @Published private(set) var ratesFromBase: [AppCurrency: Double] = [:]

    init() {
        let saved = UserDefaults.standard.string(forKey: userDefaultsKey)
        self.selectedCurrency = AppCurrency(rawValue: saved ?? baseCurrency.rawValue) ?? baseCurrency

        if let cached = loadCachedRates() {
            ratesFromBase = cached
            debugPrintRates(source: "cached API")
        } else {
            loadManualRates()
            debugPrintRates(source: "manual fallback")
        }
    }

    // MARK: - Manual rates (fallback when API fails or before first fetch)

    private func loadManualRates() {
        var rates: [AppCurrency: Double] = [:]
        for currency in AppCurrency.allCases {
            rates[currency] = rateFromBaseTo(currency)
        }
        ratesFromBase = rates
    }

    /// Manual rate from USD to the given currency. Used only as fallback.
    private func rateFromBaseTo(_ currency: AppCurrency) -> Double {
        switch currency {
        case .usd: return 1.0
        case .thb: return 35.0
        case .eur: return 0.85
        case .try_: return 34.0
        case .jpy: return 150.0
        case .cad: return 1.36
        }
    }

    // MARK: - Conversion

    /// Converts an amount from base currency (USD) to the selected display currency.
    func convertFromBase(_ amountInBase: Double) -> Double {
        let rate = ratesFromBase[selectedCurrency] ?? 1.0
        return amountInBase * rate
    }

    /// Converts an amount from the selected currency back to base (USD). Use when saving user input in display currency.
    func convertToBase(_ amountInDisplay: Double) -> Double {
        let rate = ratesFromBase[selectedCurrency] ?? 1.0
        guard rate != 0 else { return amountInDisplay }
        return amountInDisplay / rate
    }

    /// Formats an amount (in base currency) for display in the selected currency. Converts first, then formats with correct symbol.
    func format(amountInBase: Double) -> String {
        let amount = convertFromBase(amountInBase)
        return format(amount: amount, in: selectedCurrency)
    }

    /// USD equivalent per 1 unit of `currency` using current rates. Used to snapshot a rate at log time.
    func rateToUSD(for currency: AppCurrency) -> Double {
        let rate = ratesFromBase[currency] ?? 1.0
        guard rate != 0 else { return 1.0 }
        return 1.0 / rate
    }

    /// Display amount for a single transaction in the currently selected currency.
    /// Uses the original amount directly when display == original (no drift); otherwise routes through the frozen USD value.
    func displayAmount(for transaction: CDTransaction) -> Double {
        if transaction.hasCurrencySnapshot && transaction.originalCurrency == selectedCurrency {
            return transaction.originalAmount
        }
        return convertFromBase(transaction.amount)
    }

    /// Formatted display string for a single transaction in the currently selected currency.
    func format(transaction: CDTransaction) -> String {
        let amount = displayAmount(for: transaction)
        return format(amount: amount, in: selectedCurrency)
    }

    private func format(amount: Double, in currency: AppCurrency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.locale = currency.locale
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency.rawValue) \(amount)"
    }

    // MARK: - API-based rates (once per day)

    /// Fetches rates from the API if the last fetch was more than 24 hours ago. Updates `ratesFromBase` on success; keeps existing (or manual) rates on failure.
    func fetchRatesFromAPI() async {
        let now = Date()
        let last = UserDefaults.standard.object(forKey: lastRatesFetchKey) as? Date ?? .distantPast
        let elapsed = now.timeIntervalSince(last)
        let hasCachedRates = UserDefaults.standard.dictionary(forKey: cachedRatesKey) != nil
        // Honor the 24h throttle only if we actually have cached rates from a prior successful fetch.
        // Otherwise the throttle would lock us onto manual fallback for up to 24h after a stale timestamp.
        if hasCachedRates && elapsed < fetchInterval {
            #if DEBUG
            let hours = elapsed / 3600
            print("=== Currency API: skipping fetch — last successful fetch was \(String(format: "%.1f", hours))h ago (throttled to 24h) ===")
            #endif
            return
        }

        #if DEBUG
        print("=== Currency API: fetching rates… ===")
        #endif

        guard let rawRates = await CurrencyAPIService.fetchRates() else {
            #if DEBUG
            print("=== Currency API: fetch FAILED — keeping existing rates ===")
            #endif
            return
        }

        let mapped: [AppCurrency: Double] = AppCurrency.allCases.reduce(into: [:]) { result, currency in
            if let rate = rawRates[currency.rawValue], rate > 0 {
                result[currency] = rate
            } else {
                result[currency] = rateFromBaseTo(currency)
            }
        }

        await MainActor.run {
            ratesFromBase = mapped
            UserDefaults.standard.set(now, forKey: lastRatesFetchKey)
            saveCachedRates(mapped)
            debugPrintRates(source: "API")
        }
    }

    // MARK: - Rate persistence

    private func saveCachedRates(_ rates: [AppCurrency: Double]) {
        let stringKeyed = Dictionary(uniqueKeysWithValues: rates.map { ($0.key.rawValue, $0.value) })
        UserDefaults.standard.set(stringKeyed, forKey: cachedRatesKey)
    }

    private func loadCachedRates() -> [AppCurrency: Double]? {
        guard let stringKeyed = UserDefaults.standard.dictionary(forKey: cachedRatesKey) as? [String: Double],
              !stringKeyed.isEmpty else { return nil }
        var rates: [AppCurrency: Double] = [:]
        for currency in AppCurrency.allCases {
            if let rate = stringKeyed[currency.rawValue], rate > 0 {
                rates[currency] = rate
            } else {
                rates[currency] = rateFromBaseTo(currency)
            }
        }
        return rates
    }

    // MARK: - Debug

    private func debugPrintRates(source: String) {
        #if DEBUG
        print("=== Currency rates (\(source)) — base: \(baseCurrency.rawValue), selected: \(selectedCurrency.rawValue) ===")
        for currency in AppCurrency.allCases {
            let rate = ratesFromBase[currency] ?? 0
            print("  1 \(baseCurrency.rawValue) = \(rate) \(currency.rawValue)")
        }
        #endif
    }
}
