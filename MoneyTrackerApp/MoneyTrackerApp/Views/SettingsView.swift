//
//  SettingsView.swift
//  MoneyTrackerApp
//
//  Settings sheet (currency, etc.). Logic for currency to be implemented later.
//

import SwiftUI

/// Supported currencies for display and conversion.
enum AppCurrency: String, CaseIterable, Identifiable {
    case usd = "USD"
    case eur = "EUR"
    case try_ = "TRY"
    case jpy = "JPY"
    case cad = "CAD"
    case thb = "THB"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .try_: return "Turkish Lira"
        case .jpy: return "Japanese Yen"
        case .cad: return "Canadian Dollar"
        case .thb: return "Thai Baht"
        }
    }

    var label: String { "\(displayName) (\(rawValue))" }

    /// Locale used for formatting amounts in this currency.
    var locale: Locale {
        switch self {
        case .usd: return Locale(identifier: "en_US")
        case .eur: return Locale(identifier: "de_DE")
        case .try_: return Locale(identifier: "tr_TR")
        case .jpy: return Locale(identifier: "ja_JP")
        case .cad: return Locale(identifier: "en_CA")
        case .thb: return Locale(identifier: "th_TH")
        }
    }

    /// Currency symbol for input labels (e.g. $, ฿, €).
    var currencySymbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .try_: return "₺"
        case .jpy: return "¥"
        case .cad: return "C$"
        case .thb: return "฿"
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var currencyViewModel: CurrencyViewModel

    var body: some View {
        NavigationView {
            ZStack {
                Color.cyberBlack.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Currency
                        VStack(spacing: 16) {
                            CyberSectionHeader(title: "Currency")

                            VStack(spacing: 12) {
                                CyberFormRow(label: "Currency") {
                                    Picker("", selection: $currencyViewModel.selectedCurrency) {
                                        ForEach(AppCurrency.allCases) { currency in
                                            Text(currency.label).tag(currency)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.neonGreen)
                                }

                                CyberDivider()

                                Text("Amounts are stored in USD. Thai Baht uses a manual rate; other rates and API updates coming later.")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .cyberCard()
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                }
            }
            .cyberNavTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.neonGreen)
                }
            }
        }
    }
}
