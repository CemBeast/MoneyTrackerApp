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

    var icon: String {
        switch self {
        case .housing: return "house.fill"
        case .fixedBills: return "building.2.fill"
        case .food: return "fork.knife"
        case .transportation: return "car.fill"
        case .healthcare: return "cross.case.fill"
        case .funLifestyle: return "gamecontroller.fill"
        case .shopping: return "bag.fill"
        case .subscriptions: return "repeat"
        case .savings: return "banknote.fill"
        case .investing: return "chart.line.uptrend.xyaxis"
        case .travel: return "airplane"
        case .gifts: return "gift.fill"
        case .misc: return "ellipsis.circle.fill"
        }
    }
}
