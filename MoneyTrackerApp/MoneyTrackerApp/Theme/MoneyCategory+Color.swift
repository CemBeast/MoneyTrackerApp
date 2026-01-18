import SwiftUI

extension MoneyCategory {
    var color: Color {
        switch self {
        case .housing: return .neonBlue
        case .fixedBills: return .neonRed
        case .food: return .neonOrange
        case .transportation: return .neonPurple
        case .healthcare: return .neonYellow
        case .funLifestyle: return .neonPink
        case .shopping: return .neonCyan
        case .subscriptions: return .neonGreen
        case .savings: return .neonMint
        case .investing: return .neonIndigo
        case .travel: return .neonAmber
        case .gifts: return .neonMagenta
        case .misc: return .neonTeal
        }
    }
}

