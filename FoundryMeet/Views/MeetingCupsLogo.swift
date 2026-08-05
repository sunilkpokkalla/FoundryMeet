import SwiftUI

/// Pre-login loading: large centered logo with sparks drifting across on open.
struct BrandSplashView: View {
    var onFinished: () -> Void

    @State private var logoVisible = false
    @State private var sparksActive = false

    private let sparks: [SplashSpark] = SplashSpark.makeCatalog()

    var body: some View {
        GeometryReader { geo in
            let logoSide = min(geo.size.width, geo.size.height) * 0.42

            ZStack {
                AppColors.surface.ignoresSafeArea()

                // Soft warm glow behind the mark
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppColors.accentSoft.opacity(logoVisible ? 0.85 : 0),
                                AppColors.accentSoft.opacity(0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: logoSide * 0.95
                        )
                    )
                    .frame(width: logoSide * 1.8, height: logoSide * 1.8)
                    .blur(radius: 8)

                ForEach(sparks) { spark in
                    SplashSparkView(spark: spark, active: sparksActive, canvas: geo.size)
                }

                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoSide, height: logoSide)
                    .clipShape(RoundedRectangle(cornerRadius: logoSide * 0.22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.10), radius: 28, x: 0, y: 12)
                    .opacity(logoVisible ? 1 : 0)
                    .scaleEffect(logoVisible ? 1 : 0.82)
                    .accessibilityLabel("FoundryMeet")
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                logoVisible = true
            }
            // Sparks launch just after the logo settles.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                sparksActive = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeIn(duration: 0.28)) {
                    logoVisible = false
                    sparksActive = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    onFinished()
                }
            }
        }
    }
}

// MARK: - Sparks

private struct SplashSpark: Identifiable {
    let id: Int
    /// Normalized start (0…1) across the canvas.
    let startX: CGFloat
    let startY: CGFloat
    /// Direction of travel in points relative to canvas size.
    let driftX: CGFloat
    let driftY: CGFloat
    let size: CGFloat
    let delay: Double
    let duration: Double
    let rotation: Double

    static func makeCatalog() -> [SplashSpark] {
        // Deterministic layout so every open feels intentional, not random noise.
        [
            SplashSpark(id: 0, startX: 0.08, startY: 0.22, driftX: 0.55, driftY: -0.12, size: 7, delay: 0.00, duration: 1.35, rotation: 18),
            SplashSpark(id: 1, startX: 0.18, startY: 0.72, driftX: 0.48, driftY: -0.28, size: 5, delay: 0.08, duration: 1.45, rotation: -22),
            SplashSpark(id: 2, startX: 0.88, startY: 0.28, driftX: -0.52, driftY: 0.18, size: 8, delay: 0.05, duration: 1.30, rotation: 30),
            SplashSpark(id: 3, startX: 0.92, startY: 0.68, driftX: -0.60, driftY: -0.20, size: 6, delay: 0.14, duration: 1.50, rotation: -14),
            SplashSpark(id: 4, startX: 0.12, startY: 0.48, driftX: 0.70, driftY: 0.08, size: 4, delay: 0.18, duration: 1.20, rotation: 40),
            SplashSpark(id: 5, startX: 0.78, startY: 0.18, driftX: -0.35, driftY: 0.42, size: 5, delay: 0.10, duration: 1.40, rotation: -35),
            SplashSpark(id: 6, startX: 0.30, startY: 0.16, driftX: 0.25, driftY: 0.55, size: 6, delay: 0.22, duration: 1.25, rotation: 12),
            SplashSpark(id: 7, startX: 0.65, startY: 0.82, driftX: -0.40, driftY: -0.45, size: 7, delay: 0.06, duration: 1.55, rotation: -28),
            SplashSpark(id: 8, startX: 0.42, startY: 0.88, driftX: 0.30, driftY: -0.50, size: 4, delay: 0.28, duration: 1.15, rotation: 25),
            SplashSpark(id: 9, startX: 0.55, startY: 0.12, driftX: -0.20, driftY: 0.48, size: 5, delay: 0.16, duration: 1.35, rotation: -18),
            SplashSpark(id: 10, startX: 0.05, startY: 0.60, driftX: 0.42, driftY: -0.35, size: 6, delay: 0.24, duration: 1.28, rotation: 8),
            SplashSpark(id: 11, startX: 0.95, startY: 0.45, driftX: -0.55, driftY: 0.22, size: 5, delay: 0.12, duration: 1.42, rotation: -40)
        ]
    }
}

private struct SplashSparkView: View {
    let spark: SplashSpark
    let active: Bool
    let canvas: CGSize

    @State private var progress: CGFloat = 0

    var body: some View {
        let x = (spark.startX + spark.driftX * progress) * canvas.width
        let y = (spark.startY + spark.driftY * progress) * canvas.height
        // Fade in, hold, fade out along the path.
        let opacity: Double = {
            if progress < 0.12 { return Double(progress / 0.12) }
            if progress > 0.78 { return Double((1 - progress) / 0.22) }
            return 1
        }()

        Image(systemName: "sparkle")
            .font(.system(size: spark.size, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        AppColors.secondary,
                        Color(hex: 0xC4A35A),
                        AppColors.accentSoft
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .rotationEffect(.degrees(spark.rotation + Double(progress) * 40))
            .scaleEffect(0.7 + progress * 0.55)
            .opacity(active ? opacity * 0.95 : 0)
            .position(x: x, y: y)
            .allowsHitTesting(false)
            .onChange(of: active) { isActive in
                guard isActive else {
                    progress = 0
                    return
                }
                progress = 0
                withAnimation(
                    .easeInOut(duration: spark.duration)
                    .delay(spark.delay)
                ) {
                    progress = 1
                }
            }
            .onAppear {
                if active {
                    withAnimation(
                        .easeInOut(duration: spark.duration)
                        .delay(spark.delay)
                    ) {
                        progress = 1
                    }
                }
            }
    }
}

#Preview {
    BrandSplashView(onFinished: {})
}
