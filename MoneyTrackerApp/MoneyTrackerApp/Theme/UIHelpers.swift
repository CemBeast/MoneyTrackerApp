import SwiftUI

struct Toast: View {
    let text: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 16) {
            Text(text)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.neonGreen)
                }
            }
        }
        .padding(16)
        .background(Color.cyberDarkGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.neonGreen.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .neonGreenGlow, radius: 10)
        .padding()
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, _ content: @escaping () -> some View) -> some View {
        overlay(alignment: .bottom) {
            if isPresented.wrappedValue {
                content()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { isPresented.wrappedValue = false }
                        }
                    }
            }
        }
    }
}

// MARK: - Empty State View
struct CyberEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.neonGreen.opacity(0.3))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
            
            if let buttonTitle, let buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.cyberBlack)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.neonGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .neonGreenGlow, radius: 8)
                }
                .padding(.top, 8)
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Loading Indicator
struct CyberLoadingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.neonGreen, lineWidth: 3)
            .frame(width: 40, height: 40)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Numeric Keypad Input
struct CyberAmountInput: View {
    @Binding var amount: String
    var color: Color = .neonGreen
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("$")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color.opacity(0.7))
            
            TextField("0.00", text: $amount)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.leading)
        }
        .shadow(color: color.opacity(0.3), radius: 8)
    }
}
