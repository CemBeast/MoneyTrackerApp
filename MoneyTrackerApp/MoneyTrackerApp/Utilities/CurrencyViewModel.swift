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
        loadManualRates()
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = selectedCurrency.rawValue
        formatter.locale = selectedCurrency.locale
        return formatter.string(from: NSNumber(value: amount)) ?? "\(selectedCurrency.rawValue) \(amount)"
    }

    // MARK: - API-based rates (once per day)

    /// Fetches rates from the API if the last fetch was more than 24 hours ago. Updates `ratesFromBase` on success; keeps existing (or manual) rates on failure.
    func fetchRatesFromAPI() async {
        let now = Date()
        let last = UserDefaults.standard.object(forKey: lastRatesFetchKey) as? Date ?? .distantPast
        guard now.timeIntervalSince(last) >= fetchInterval else { return }

        guard let rawRates = await CurrencyAPIService.fetchRates() else { return }

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
        }
    }
}
