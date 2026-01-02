import SwiftUI

// MARK: - App Icon Design System
struct AppIconView: View {
    let size: CGFloat
    
    init(size: CGFloat = 64) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: size * 0.225)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.0, green: 0.3, blue: 0.8),
                            Color(red: 0.0, green: 0.6, blue: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Electrical circuit pattern background
            CircuitPattern()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .frame(width: size * 0.8, height: size * 0.8)
            
            // Main lightning bolt
            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white,
                            Color.yellow.opacity(0.9)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
            
            // Network signal waves
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        Color.white.opacity(0.3 - Double(index) * 0.1),
                        lineWidth: 2
                    )
                    .frame(width: size * (0.6 + Double(index) * 0.15))
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Circuit Pattern for Background
struct CircuitPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Create a simple circuit pattern
        path.move(to: CGPoint(x: width * 0.2, y: height * 0.2))
        path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.2))
        path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.5))
        path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.5))
        
        path.move(to: CGPoint(x: width * 0.4, y: height * 0.5))
        path.addLine(to: CGPoint(x: width * 0.2, y: height * 0.5))
        path.addLine(to: CGPoint(x: width * 0.2, y: height * 0.8))
        path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.8))
        
        // Add connection points
        let connectionPoints = [
            CGPoint(x: width * 0.3, y: height * 0.2),
            CGPoint(x: width * 0.6, y: height * 0.2),
            CGPoint(x: width * 0.3, y: height * 0.5),
            CGPoint(x: width * 0.7, y: height * 0.5),
            CGPoint(x: width * 0.4, y: height * 0.8),
            CGPoint(x: width * 0.7, y: height * 0.8),
        ]
        
        for point in connectionPoints {
            path.addEllipse(in: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
        }
        
        return path
    }
}

// MARK: - Status Icons
struct StatusIcons {
    static func deviceOnline(size: CGFloat = 16) -> some View {
        ZStack {
            Circle()
                .fill(Color.successGreen)
                .frame(width: size, height: size)
            
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.6, weight: .bold))
                .foregroundColor(.white)
        }
        .shadow(color: .successGreen.opacity(0.4), radius: 4)
    }
    
    static func deviceOffline(size: CGFloat = 16) -> some View {
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: size, height: size)
            
            Image(systemName: "minus")
                .font(.system(size: size * 0.6, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    static func wakeSignal(size: CGFloat = 24) -> some View {
        ZStack {
            // Pulsing background
            Circle()
                .fill(Color.primaryBlue.opacity(0.2))
                .frame(width: size * 1.5, height: size * 1.5)
                .scaleEffect(1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: UUID()
                )
            
            // Main icon
            Image(systemName: "wifi.circle.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(.primaryBlue)
                .symbolRenderingMode(.hierarchical)
        }
    }
    
    static func quickWake(size: CGFloat = 16) -> some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.primaryBlue.opacity(0.15))
                .frame(width: size * 1.5, height: size * 1.5)
            
            // Lightning bolt icon
            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.7, weight: .bold))
                .foregroundColor(.primaryBlue)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

// MARK: - Device Type Icons
// Note: DeviceType enum is now defined in WakeOnLANViewModel.swift to avoid conflicts

struct DeviceIconView: View {
    let deviceType: DeviceType
    let isOnline: Bool
    let size: CGFloat
    
    init(_ deviceType: DeviceType, isOnline: Bool = false, size: CGFloat = 32) {
        self.deviceType = deviceType
        self.isOnline = isOnline
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(isOnline ? Color.primaryBlue.opacity(0.1) : Color.gray.opacity(0.1))
                .frame(width: size, height: size)
            
            // Device icon
            Image(systemName: deviceType.icon)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundColor(isOnline ? .primaryBlue : .gray)
                .symbolRenderingMode(.hierarchical)
            
            // Online indicator
            if isOnline {
                VStack {
                    HStack {
                        Spacer()
                        StatusIcons.deviceOnline(size: size * 0.3)
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Animated Elements
struct PulsingDot: View {
    @State private var isAnimating = false
    let color: Color
    let size: CGFloat
    
    init(color: Color = .primaryBlue, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(isAnimating ? 1.5 : 1.0)
                .opacity(isAnimating ? 0.0 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct WifiWaves: View {
    @State private var animationPhase: Double = 0
    let strength: Int // 1-3
    let color: Color
    let size: CGFloat
    
    init(strength: Int = 3, color: Color = .primaryBlue, size: CGFloat = 24) {
        self.strength = max(1, min(3, strength))
        self.color = color
        self.size = size
    }
    
    var body: some View {
        ZStack {
            ForEach(1...strength, id: \.self) { index in
                Circle()
                    .stroke(
                        color.opacity(0.8 - Double(index - 1) * 0.2),
                        lineWidth: 2
                    )
                    .frame(width: size * Double(index) * 0.4)
                    .scaleEffect(1.0 + sin(animationPhase + Double(index) * 0.5) * 0.1)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
    }
}

// MARK: - Network Activity Indicator
struct NetworkActivityIndicator: View {
    @State private var animationOffset: CGFloat = 0
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(isActive ? Color.primaryBlue : Color.gray.opacity(0.3))
                    .frame(width: 3, height: CGFloat.random(in: 8...16))
                    .scaleEffect(y: isActive ? (0.3 + 0.7 * (1 + sin(animationOffset + Double(index) * 0.5)) / 2) : 0.3)
                    .animation(
                        isActive ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            if isActive {
                withAnimation {
                    animationOffset = .pi * 2
                }
            }
        }
        .onChange(of: isActive) {
            if isActive {
                withAnimation {
                    animationOffset = .pi * 2
                }
            } else {
                animationOffset = 0
            }
        }
    }
}

// MARK: - Preview Container
struct IconSystemPreviews: View {
    var body: some View {
        VStack(spacing: 32) {
            // App Icon
            HStack {
                Text("App Icon")
                    .font(.headline)
                Spacer()
                AppIconView(size: 64)
            }
            
            // Device Icons
            VStack(alignment: .leading, spacing: 16) {
                Text("Device Types")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(DeviceType.allCases, id: \.self) { deviceType in
                        VStack {
                            DeviceIconView(deviceType, isOnline: Bool.random(), size: 48)
                            Text(deviceType.displayName)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            
            // Status Indicators
            VStack(alignment: .leading, spacing: 16) {
                Text("Status Indicators")
                    .font(.headline)
                
                HStack(spacing: 32) {
                    VStack {
                        StatusIcons.deviceOnline(size: 24)
                        Text("Online")
                            .font(.caption)
                    }
                    
                    VStack {
                        StatusIcons.deviceOffline(size: 24)
                        Text("Offline")
                            .font(.caption)
                    }
                    
                    VStack {
                        StatusIcons.wakeSignal(size: 24)
                        Text("Wake Signal")
                            .font(.caption)
                    }
                    
                    VStack {
                        StatusIcons.quickWake(size: 24)
                        Text("Quick Wake")
                            .font(.caption)
                    }
                }
            }
            
            // Animated Elements
            VStack(alignment: .leading, spacing: 16) {
                Text("Animated Elements")
                    .font(.headline)
                
                HStack(spacing: 32) {
                    VStack {
                        PulsingDot(color: .primaryBlue, size: 12)
                        Text("Pulsing")
                            .font(.caption)
                    }
                    
                    VStack {
                        WifiWaves(strength: 3, size: 32)
                        Text("WiFi Waves")
                            .font(.caption)
                    }
                    
                    VStack {
                        NetworkActivityIndicator(isActive: true)
                        Text("Network Activity")
                            .font(.caption)
                    }
                }
            }
        }
        .padding(32)
        .background(Color.appBackground)
        .foregroundColor(.textPrimary)
    }
}

// MARK: - Preview
struct IconSystemPreviews_Previews: PreviewProvider {
    static var previews: some View {
        IconSystemPreviews()
            .frame(width: 800, height: 900)
    }
}