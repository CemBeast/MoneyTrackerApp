//
//  CurrencyAPIService.swift
//  MoneyTrackerApp
//
//  Fetches USD-based exchange rates from https://open.er-api.com (no API key required).
//  See: https://www.exchangerate-api.com/docs/free
//

import Foundation

/// Response shape from https://open.er-api.com/v6/latest/USD
struct ExchangeRateResponse: Decodable {
    let result: String?
    let baseCode: String?
    let rates: [String: Double]?
    let timeLastUpdateUnix: Int?

    enum CodingKeys: String, CodingKey {
        case result
        case baseCode = "base_code"
        case rates
        case timeLastUpdateUnix = "time_last_update_unix"
    }
}

enum CurrencyAPIService {
    private static let endpoint = URL(string: "https://open.er-api.com/v6/latest/USD")!

    /// Fetches latest USD-based rates. Returns a dictionary of currency code (e.g. "THB") to rate (units per 1 USD), or nil on failure.
    static func fetchRates() async -> [String: Double]? {
        do {
            let (data, response) = try await URLSession.shared.data(from: endpoint)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            let decoded = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            guard decoded.result == "success", let rates = decoded.rates else {
                return nil
            }

            return rates
        } catch {
            return nil
        }
    }
}
