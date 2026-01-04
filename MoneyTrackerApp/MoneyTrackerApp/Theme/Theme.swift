import SwiftUI

// MARK: - Cyberpunk Theme Colors
extension Color {
    static let cyberBlack = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let cyberDarkGray = Color(red: 0.1, green: 0.1, blue: 0.12)
    static let cyberGray = Color(red: 0.15, green: 0.15, blue: 0.18)
    static let cyberLightGray = Color(red: 0.25, green: 0.25, blue: 0.28)
    
    static let neonGreen = Color(red: 0.2, green: 1.0, blue: 0.4)
    static let neonGreenDim = Color(red: 0.15, green: 0.7, blue: 0.3)
    static let neonGreenGlow = Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.3)
    
    static let neonPink = Color(red: 1.0, green: 0.2, blue: 0.6)
    static let neonBlue = Color(red: 0.2, green: 0.8, blue: 1.0)
    static let neonPurple = Color(red: 0.7, green: 0.3, blue: 1.0)
    static let neonOrange = Color(red: 1.0, green: 0.5, blue: 0.2)
    static let neonYellow = Color(red: 1.0, green: 0.9, blue: 0.2)
    static let neonRed = Color(red: 1.0, green: 0.3, blue: 0.3)
    
    // Category colors for charts
    static let cyberChartColors: [Color] = [
        .neonGreen, .neonBlue, .neonPink, .neonPurple, .neonOrange, .neonYellow, .neonRed
    ]
}

// MARK: - Cyberpunk Card Style
struct CyberCard: ViewModifier {
    var glowColor: Color = .neonGreen
    var showGlow: Bool = true
    
    func body(content: Content) -> some View {
        content
            .background(Color.cyberDarkGray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(glowColor.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: showGlow ? glowColor.opacity(0.2) : .clear, radius: 8, x: 0, y: 0)
    }
}

extension View {
    func cyberCard(glowColor: Color = .neonGreen, showGlow: Bool = true) -> some View {
        modifier(CyberCard(glowColor: glowColor, showGlow: showGlow))
    }
}

// MARK: - Cyberpunk Button Style
struct CyberButtonStyle: ButtonStyle {
    var isProminent: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(isProminent ? .cyberBlack : .neonGreen)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                isProminent ? Color.neonGreen : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.neonGreen, lineWidth: isProminent ? 0 : 1)
            )
            .shadow(color: .neonGreenGlow, radius: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Cyberpunk Small Button Style
struct CyberSmallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.neonGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.cyberGray)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.neonGreen.opacity(0.5), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Cyberpunk Icon Button Style
struct CyberIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.neonGreen)
            .padding(8)
            .background(Color.cyberGray)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.neonGreen.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .neonGreenGlow, radius: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Cyberpunk Text Field Style
struct CyberTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color.cyberGray)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.neonGreen.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Cyberpunk List Row
struct CyberListRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.cyberDarkGray)
            .listRowSeparatorTint(Color.neonGreen.opacity(0.2))
    }
}

extension View {
    func cyberListRow() -> some View {
        modifier(CyberListRow())
    }
}

// MARK: - Cyberpunk Navigation Title
struct CyberNavTitle: ViewModifier {
    let title: String
    
    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.cyberBlack, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

extension View {
    func cyberNavTitle(_ title: String) -> some View {
        modifier(CyberNavTitle(title: title))
    }
}

// MARK: - Glow Text
struct GlowText: View {
    let text: String
    var font: Font = .headline
    var color: Color = .neonGreen
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .shadow(color: color.opacity(0.8), radius: 2)
    }
}

// MARK: - Cyberpunk Progress Bar
struct CyberProgressBar: View {
    let progress: Double
    var barColor: Color = .neonGreen
    var isOverBudget: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.cyberGray)
                    .frame(height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: isOverBudget ? [.neonRed, .neonOrange] : [barColor, barColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)), height: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: (isOverBudget ? Color.neonRed : barColor).opacity(0.5), radius: 4)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Cyberpunk Tag
struct CyberTag: View {
    let text: String
    var color: Color = .neonGreen
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
    }
}

// MARK: - Cyberpunk Stat Display
struct CyberStat: View {
    let title: String
    let value: String
    var valueColor: Color = .neonGreen
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(Color.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(1)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(valueColor)
                .shadow(color: valueColor.opacity(0.5), radius: 4)
        }
    }
}

// MARK: - Cyberpunk Section Header
struct CyberSectionHeader: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.neonGreen)
                .frame(width: 3, height: 16)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.neonGreen)
                .textCase(.uppercase)
                .tracking(2)
            
            Spacer()
        }
    }
}

// MARK: - Cyberpunk Divider
struct CyberDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.neonGreen.opacity(0), Color.neonGreen.opacity(0.5), Color.neonGreen.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

