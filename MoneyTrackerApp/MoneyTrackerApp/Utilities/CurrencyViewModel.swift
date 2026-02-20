//
//  CurrencyViewModel.swift
//  MoneyTrackerApp
//
//  Handles selected currency and conversion. Amounts are stored in base currency (USD).
//  Designed so conversion rates can later be loaded from an API.
//

import Foundation
import SwiftUI
import Combine

/// Base currency for stored amounts. All amounts in the app are in USD.
private let baseCurrency = AppCurrency.usd

final class CurrencyViewModel: ObservableObject {
    private let userDefaultsKey = "MoneyTracker.selectedCurrency"

    /// Currently selected display currency.
    @Published var selectedCurrency: AppCurrency {
        didSet {
            UserDefaults.standard.set(selectedCurrency.rawValue, forKey: userDefaultsKey)
        }
    }

    /// Conversion rates from base (USD) to each currency. Only THB is set manually for now; others are 1.0 (no conversion). Replace with API-fetched rates later.
    @Published private(set) var ratesFromBase: [AppCurrency: Double] = [:]

    init() {
        let saved = UserDefaults.standard.string(forKey: userDefaultsKey)
        self.selectedCurrency = AppCurrency(rawValue: saved ?? baseCurrency.rawValue) ?? baseCurrency
        loadManualRates()
    }

    // MARK: - Manual rates (only Thai Baht for now)

    private func loadManualRates() {
        var rates: [AppCurrency: Double] = [:]
        for currency in AppCurrency.allCases {
            rates[currency] = rateFromBaseTo(currency)
        }
        ratesFromBase = rates
    }

    /// Manual rate from USD to the given currency. Only THB is defined; others return 1.0 until we add API or more manual rates.
    private func rateFromBaseTo(_ currency: AppCurrency) -> Double {
        switch currency {
        case .usd: return 1.0
        case .thb: return 35.0  // Manual: 1 USD ≈ 35 THB (update or replace with API later)
        case .eur, .try_, .jpy, .cad: return 1.0  // No conversion yet
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = selectedCurrency.rawValue
        formatter.locale = selectedCurrency.locale
        return formatter.string(from: NSNumber(value: amount)) ?? "\(selectedCurrency.rawValue) \(amount)"
    }

    // MARK: - Future: API-based rates

    /// Call this later to fetch up-to-date rates from an API. For now, does nothing.
    func fetchRatesFromAPI() async {
        // TODO: e.g. fetch from exchangerate-api.com or similar, then update ratesFromBase
        // Example shape:
        // let rates = await someAPIClient.fetchRates(base: "USD")
        // await MainActor.run { self.ratesFromBase = rates }
    }
}
