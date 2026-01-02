import SwiftUI
import Combine

// MARK: - Modern Interaction System
struct InteractionEffects {
    
    // MARK: - Haptic Feedback Manager
    class HapticFeedbackManager {
        static let shared = HapticFeedbackManager()
        
        private init() {}
        
        func impact(_ style: ImpactStyle = .medium) {
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: style.uiKitStyle)
            impactFeedback.impactOccurred()
            #endif
        }
        
        func notification(_ type: NotificationType) {
            #if os(iOS)
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(type.uiKitType)
            #endif
        }
        
        func selection() {
            #if os(iOS)
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
            #endif
        }
        
        enum ImpactStyle {
            case light, medium, heavy
            
            #if os(iOS)
            var uiKitStyle: UIImpactFeedbackGenerator.FeedbackStyle {
                switch self {
                case .light: return .light
                case .medium: return .medium
                case .heavy: return .heavy
                }
            }
            #endif
        }
        
        enum NotificationType {
            case success, warning, error
            
            #if os(iOS)
            var uiKitType: UINotificationFeedbackGenerator.FeedbackType {
                switch self {
                case .success: return .success
                case .warning: return .warning
                case .error: return .error
                }
            }
            #endif
        }
    }
    
    // MARK: - Liquid Glass Effect
    struct LiquidGlassEffect: View {
        let content: AnyView
        @State private var isHovered = false
        @State private var touchPoint: CGPoint = .zero
        
        init<Content: View>(@ViewBuilder content: () -> Content) {
            self.content = AnyView(content())
        }
        
        var body: some View {
            content
                .background(
                    ZStack {
                        // Base glass material
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                        
                        // Dynamic reflection overlay
                        if isHovered {
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ]),
                                center: UnitPoint(
                                    x: touchPoint.x / 800, // Use fixed width instead of UIScreen
                                    y: touchPoint.y / 600  // Use fixed height instead of UIScreen
                                ),
                                startRadius: 10,
                                endRadius: 100
                            )
                            .blendMode(.overlay)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        
                        // Shimmer effect
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(isHovered ? 0.1 : 0.05),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isHovered = hovering
                    }
                }
                .onTapGesture { location in
                    touchPoint = location
                }
        }
    }
    
    // MARK: - Morphing Button
    struct MorphingButton<Content: View>: View {
        let content: Content
        let action: () -> Void
        
        @State private var isPressed = false
        @State private var morphScale: CGFloat = 1.0
        @State private var rippleAnimation = false
        
        init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
            self.action = action
            self.content = content()
        }
        
        var body: some View {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    rippleAnimation.toggle()
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    action()
                    HapticFeedbackManager.shared.impact(.light)
                }
            }) {
                ZStack {
                    // Ripple effect
                    Circle()
                        .fill(Color.primaryBlue.opacity(0.3))
                        .scaleEffect(rippleAnimation ? 1.5 : 0.8)
                        .opacity(rippleAnimation ? 0 : 1)
                        .animation(.easeOut(duration: 0.5), value: rippleAnimation)
                    
                    // Button content
                    content
                        .scaleEffect(morphScale)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, perform: {}, onPressingChanged: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                    morphScale = pressing ? 0.98 : 1.0
                }
            })
        }
    }
    
    // MARK: - Particle System
    struct ParticleSystem: View {
        @State private var particles: [Particle] = []
        let maxParticles = 20
        
        struct Particle: Identifiable {
            let id = UUID()
            var position: CGPoint
            var velocity: CGVector
            var life: Double
            var maxLife: Double
            var color: Color
            var size: CGFloat
        }
        
        var body: some View {
            Canvas { context, size in
                for particle in particles {
                    let opacity = particle.life / particle.maxLife
                    let currentSize = particle.size * opacity
                    
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: particle.position.x - currentSize/2,
                            y: particle.position.y - currentSize/2,
                            width: currentSize,
                            height: currentSize
                        )),
                        with: .color(particle.color.opacity(opacity))
                    )
                }
            }
            .onAppear {
                startParticleSystem()
            }
        }
        
        private func startParticleSystem() {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                updateParticles()
                if particles.count < maxParticles {
                    addParticle()
                }
            }
        }
        
        private func addParticle() {
            let newParticle = Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...400),
                    y: CGFloat.random(in: 0...300)
                ),
                velocity: CGVector(
                    dx: CGFloat.random(in: -2...2),
                    dy: CGFloat.random(in: -2...2)
                ),
                life: 3.0,
                maxLife: 3.0,
                color: [Color.primaryBlue, Color.successGreen, Color.warningYellow].randomElement()!,
                size: CGFloat.random(in: 2...6)
            )
            particles.append(newParticle)
        }
        
        private func updateParticles() {
            particles = particles.compactMap { particle in
                var updatedParticle = particle
                updatedParticle.position.x += particle.velocity.dx
                updatedParticle.position.y += particle.velocity.dy
                updatedParticle.life -= 0.1
                
                return updatedParticle.life > 0 ? updatedParticle : nil
            }
        }
    }
    
    // MARK: - Floating Action Button
    struct FloatingActionButton: View {
        let icon: String
        let action: () -> Void
        
        @State private var isExpanded = false
        @State private var rotationAngle: Double = 0
        
        var body: some View {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                            rotationAngle += 180
                        }
                        action()
                        HapticFeedbackManager.shared.impact(.medium)
                    }) {
                        Image(systemName: icon)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.primaryBlue, Color.primaryBlue.opacity(0.8)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: .primaryBlue.opacity(0.4), radius: 12, x: 0, y: 6)
                            .scaleEffect(isExpanded ? 1.1 : 1.0)
                            .rotationEffect(.degrees(rotationAngle))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Toast Notification
    struct ToastNotification: View {
        let message: String
        let type: ToastType
        @Binding var isShowing: Bool
        
        enum ToastType {
            case success, error, warning, info
            
            var color: Color {
                switch self {
                case .success: return .successGreen
                case .error: return .errorRed
                case .warning: return .warningYellow
                case .info: return .primaryBlue
                }
            }
            
            var icon: String {
                switch self {
                case .success: return "checkmark.circle.fill"
                case .error: return "xmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .info: return "info.circle.fill"
                }
            }
        }
        
        var body: some View {
            VStack {
                Spacer()
                
                HStack {
                    Image(systemName: type.icon)
                        .foregroundColor(type.color)
                        .font(.title3)
                    
                    Text(message)
                        .foregroundColor(.textPrimary)
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.textSecondary)
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(type.color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Loading Shimmer Effect
    struct ShimmerEffect: View {
        @State private var shimmerLocation: CGFloat = -1
        
        var body: some View {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.white.opacity(0.3),
                    Color.clear
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: shimmerLocation * 800) // Use fixed width instead of UIScreen
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerLocation = 1
                }
            }
        }
    }
    
    // MARK: - Progress Ring
    struct ProgressRing: View {
        let progress: Double
        let lineWidth: CGFloat
        let size: CGFloat
        
        init(progress: Double, lineWidth: CGFloat = 8, size: CGFloat = 60) {
            self.progress = progress
            self.lineWidth = lineWidth
            self.size = size
        }
        
        var body: some View {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.borderColor, lineWidth: lineWidth)
                    .frame(width: size, height: size)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.primaryBlue, Color.successGreen]),
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Center text
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.25, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
            }
        }
    }
}

// MARK: - Modern View Modifiers
extension View {
    func liquidGlass() -> some View {
        InteractionEffects.LiquidGlassEffect {
            self
        }
    }
    
    func shimmerEffect(isActive: Bool = true) -> some View {
        overlay(
            isActive ? InteractionEffects.ShimmerEffect() : nil
        )
        .clipped()
    }
    
    func morphingButton(action: @escaping () -> Void) -> some View {
        InteractionEffects.MorphingButton(action: action) {
            self
        }
    }
    
    func hapticFeedback(_ type: InteractionEffects.HapticFeedbackManager.ImpactStyle = .medium) -> some View {
        onTapGesture {
            InteractionEffects.HapticFeedbackManager.shared.impact(type)
        }
    }
}

// MARK: - Toast Manager
class ToastManager: ObservableObject {
    @Published var toasts: [ToastItem] = []
    
    struct ToastItem: Identifiable {
        let id = UUID()
        let message: String
        let type: InteractionEffects.ToastNotification.ToastType
    }
    
    func show(_ message: String, type: InteractionEffects.ToastNotification.ToastType = .info) {
        let toast = ToastItem(message: message, type: type)
        withAnimation(.spring()) {
            toasts.append(toast)
        }
        
        // Auto-remove after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut) {
                self.toasts.removeAll { $0.id == toast.id }
            }
        }
    }
    
    func remove(_ toast: ToastItem) {
        withAnimation(.easeInOut) {
            toasts.removeAll { $0.id == toast.id }
        }
    }
}

// MARK: - Toast Overlay View
struct ToastOverlayView: View {
    @StateObject private var toastManager = ToastManager()
    
    var body: some View {
        ZStack {
            ForEach(Array(toastManager.toasts.enumerated()), id: \.element.id) { index, toast in
                InteractionEffects.ToastNotification(
                    message: toast.message,
                    type: toast.type,
                    isShowing: .constant(true)
                )
                .offset(y: CGFloat(index) * -80)
                .zIndex(Double(toastManager.toasts.count - index))
            }
        }
        .environmentObject(toastManager)
    }
}

// MARK: - Demo View
struct ModernInteractionsDemo: View {
    @StateObject private var toastManager = ToastManager()
    @State private var progress: Double = 0.7
    @State private var showParticles = false
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 32) {
                    Text("Modern UI Interactions")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    // Liquid Glass Cards
                    VStack(spacing: 16) {
                        Text("Liquid Glass Effects")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        VStack(spacing: 16) {
                            Text("Hover over this card")
                                .padding(24)
                                .liquidGlass()
                            
                            HStack {
                                Button("Success") {
                                    toastManager.show("Operation completed successfully!", type: .success)
                                }
                                .buttonStyle(ModernButtonStyle(.primary))
                                .morphingButton {
                                    toastManager.show("Morphing button tapped!", type: .info)
                                }
                                
                                Button("Warning") {
                                    toastManager.show("This is a warning message", type: .warning)
                                }
                                .buttonStyle(ModernButtonStyle(.secondary))
                                
                                Button("Error") {
                                    toastManager.show("Something went wrong!", type: .error)
                                }
                                .buttonStyle(ModernButtonStyle(.danger))
                            }
                            .liquidGlass()
                        }
                    }
                    
                    // Progress Rings
                    VStack(spacing: 16) {
                        Text("Progress Indicators")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        HStack(spacing: 24) {
                            InteractionEffects.ProgressRing(progress: 0.3)
                            InteractionEffects.ProgressRing(progress: progress)
                            InteractionEffects.ProgressRing(progress: 0.9)
                        }
                        
                        Slider(value: $progress, in: 0...1)
                            .accentColor(.primaryBlue)
                    }
                    .liquidGlass()
                    
                    // Particle System Toggle
                    VStack {
                        Toggle("Show Particles", isOn: $showParticles)
                            .toggleStyle(SwitchToggleStyle(tint: .primaryBlue))
                        
                        if showParticles {
                            InteractionEffects.ParticleSystem()
                                .frame(height: 200)
                        }
                    }
                    .liquidGlass()
                }
                .padding(32)
            }
            
            // Floating Action Button
            InteractionEffects.FloatingActionButton(icon: "plus") {
                toastManager.show("FAB tapped!", type: .info)
            }
            
            // Toast Overlay
            ForEach(Array(toastManager.toasts.enumerated()), id: \.element.id) { index, toast in
                InteractionEffects.ToastNotification(
                    message: toast.message,
                    type: toast.type,
                    isShowing: .constant(true)
                )
                .offset(y: CGFloat(index) * -80)
                .zIndex(Double(toastManager.toasts.count - index))
            }
        }
        .background(Color.appBackground)
        .environmentObject(toastManager)
    }
}

// MARK: - Preview
struct ModernInteractionsDemo_Previews: PreviewProvider {
    static var previews: some View {
        ModernInteractionsDemo()
            .frame(width: 800, height: 900)
    }
}