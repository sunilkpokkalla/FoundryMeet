import SwiftUI
import UIKit

/// Brand mark: two cups toast together. Used only on the pre-login splash.
struct MeetingCupsLogo: View {
    var size: CGFloat = 96
    var joined: Bool
    var sparks: Bool
    var settled: Bool
    var flash: Bool

    var body: some View {
        ZStack {
            // Soft warm bloom behind the mark — feels like café light, not neon.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0xC9A86A).opacity(flash ? 0.35 : 0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: size * 0.85
                    )
                )
                .frame(width: size * 1.55, height: size * 1.55)
                .blur(radius: 8)
                .scaleEffect(flash ? 1.08 : 0.92)
                .opacity(settled || joined ? 1 : 0.4)

            // Expanding clink ring
            Circle()
                .stroke(Color(hex: 0xC9A86A).opacity(flash ? 0.45 : 0), lineWidth: 2)
                .frame(width: size * 0.9, height: size * 0.9)
                .scaleEffect(flash ? 1.55 : 0.7)
                .opacity(flash ? 0 : 0.5)

            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.18), radius: settled ? 18 : 8, y: settled ? 10 : 4)

                ZStack {
                    cup(side: .left)
                        .offset(
                            x: joined ? -size * 0.012 : -size * 0.28,
                            y: joined ? 0 : size * 0.04
                        )
                        .rotationEffect(.degrees(joined ? 0 : -11))

                    cup(side: .right)
                        .offset(
                            x: joined ? size * 0.012 : size * 0.28,
                            y: joined ? 0 : size * 0.04
                        )
                        .rotationEffect(.degrees(joined ? 0 : 11))

                    sparkBurst
                        .opacity(sparks ? 1 : 0)
                        .scaleEffect(sparks ? 1 : 0.35)
                        .offset(y: sparks ? 0 : size * 0.04)

                    steamWisps
                        .opacity(settled ? 0.7 : 0)
                        .offset(y: settled ? -size * 0.02 : size * 0.04)
                }
                .padding(size * 0.14)
            }
            .frame(width: size, height: size)
            .scaleEffect(settled ? 1 : (joined ? 1.04 : 0.94))
        }
        .frame(width: size * 1.6, height: size * 1.6)
        .accessibilityLabel("FoundryMeet")
    }

    private enum Side { case left, right }

    private func cup(side: Side) -> some View {
        let stroke = size * 0.075
        let cupW = size * 0.38
        let cupH = size * 0.42
        let handleW = size * 0.16
        let handleH = size * 0.22
        let cream = Color(hex: 0xE8DFD0)

        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
                .strokeBorder(cream, lineWidth: stroke)
                .frame(width: cupW, height: cupH)

            Capsule()
                .fill(cream)
                .frame(width: stroke * 0.85, height: cupH * 0.55)
                .offset(
                    x: side == .left ? -cupW * 0.12 : cupW * 0.12,
                    y: -cupH * 0.02
                )

            Capsule()
                .strokeBorder(cream, lineWidth: stroke * 0.9)
                .frame(width: handleW, height: handleH)
                .offset(x: side == .left ? -(cupW / 2 + handleW * 0.15) : cupW / 2 + handleW * 0.15)
        }
        .frame(width: size * 0.7, height: size * 0.55)
    }

    private var sparkBurst: some View {
        let length = size * 0.11
        let cream = Color(hex: 0xE8DFD0)
        return ZStack {
            ForEach(Array([-42.0, 0.0, 42.0].enumerated()), id: \.offset) { index, angle in
                Capsule()
                    .fill(cream)
                    .frame(width: size * 0.032, height: length * (angle == 0 ? 1 : 0.82))
                    .rotationEffect(.degrees(angle))
                    .offset(
                        x: sin(angle * .pi / 180) * size * 0.1,
                        y: -size * 0.18 - abs(angle) * 0.001
                    )
                    .opacity(sparks ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.28).delay(Double(index) * 0.04),
                        value: sparks
                    )
            }
        }
    }

    private var steamWisps: some View {
        HStack(spacing: size * 0.08) {
            Capsule()
                .fill(Color(hex: 0xE8DFD0).opacity(0.35))
                .frame(width: size * 0.03, height: size * 0.14)
                .offset(y: -size * 0.28)
            Capsule()
                .fill(Color(hex: 0xE8DFD0).opacity(0.22))
                .frame(width: size * 0.025, height: size * 0.11)
                .offset(y: -size * 0.3)
            Capsule()
                .fill(Color(hex: 0xE8DFD0).opacity(0.28))
                .frame(width: size * 0.03, height: size * 0.13)
                .offset(y: -size * 0.27)
        }
        .blur(radius: 1.2)
    }
}

/// Full-screen brand moment before the login form. Cups toast at most once per day.
struct BrandSplashView: View {
    var onFinished: () -> Void

    private static let lastPlayedKey = "meetingCupsLogoLastPlayedDay"

    @State private var shouldAnimate = false
    @State private var ready = false

    @State private var atmosphere = false
    @State private var joined = false
    @State private var sparks = false
    @State private var flash = false
    @State private var settled = false
    @State private var showWordmark = false
    @State private var showTagline = false
    @State private var exitFade = false

    var body: some View {
        ZStack {
            atmosphereBackground

            VStack(spacing: 28) {
                Spacer(minLength: 0)

                MeetingCupsLogo(
                    size: 120,
                    joined: joined,
                    sparks: sparks,
                    settled: settled,
                    flash: flash
                )

                VStack(spacing: 10) {
                    Text("FoundryMeet")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.8)
                        .foregroundColor(AppColors.onSurface)
                        .opacity(showWordmark ? 1 : 0)
                        .offset(y: showWordmark ? 0 : 12)

                    Text("Two cups. One conversation.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.secondary)
                        .opacity(showTagline ? 1 : 0)
                        .offset(y: showTagline ? 0 : 8)
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 0)
            }
            .padding(.bottom, 40)
        }
        .opacity(exitFade ? 0 : 1)
        .scaleEffect(exitFade ? 1.02 : 1)
        .onAppear {
            guard !ready else { return }
            ready = true
            configureAndPlay()
        }
    }

    private var atmosphereBackground: some View {
        ZStack {
            AppColors.surface

            // Warm paper wash — coffee-shop morning, not a tech gradient.
            RadialGradient(
                colors: [
                    Color(hex: 0xF3E7D0).opacity(atmosphere ? 0.85 : 0.35),
                    Color(hex: 0xF7F7F5).opacity(0.2),
                    AppColors.surface
                ],
                center: .init(x: 0.5, y: 0.38),
                startRadius: 20,
                endRadius: 420
            )

            // Soft vignette so the mark reads as the stage.
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(atmosphere ? 0.04 : 0.02)
                ],
                center: .center,
                startRadius: 160,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }

    private func configureAndPlay() {
        let today = Self.dayStamp()
        let last = UserDefaults.standard.string(forKey: Self.lastPlayedKey)
        shouldAnimate = last != today
        if shouldAnimate {
            UserDefaults.standard.set(today, forKey: Self.lastPlayedKey)
            playFullToast()
        } else {
            playQuietReveal()
        }
    }

    /// Full daily brand moment: approach → toast → wordmark.
    private func playFullToast() {
        withAnimation(.easeOut(duration: 0.55)) {
            atmosphere = true
        }

        withAnimation(.spring(response: 0.78, dampingFraction: 0.78).delay(0.28)) {
            joined = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.22)) {
                sparks = true
                flash = true
            }
            withAnimation(.easeOut(duration: 0.55).delay(0.12)) {
                flash = false
            }
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(1.05)) {
            settled = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(1.15)) {
            showWordmark = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(1.4)) {
            showTagline = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.35) {
            finish()
        }
    }

    /// Same day reopen: still a quiet brand beat, no toast replay.
    private func playQuietReveal() {
        joined = true
        sparks = true
        settled = true
        withAnimation(.easeOut(duration: 0.4)) {
            atmosphere = true
            showWordmark = true
        }
        withAnimation(.easeOut(duration: 0.35).delay(0.15)) {
            showTagline = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            finish()
        }
    }

    private func finish() {
        withAnimation(.easeIn(duration: 0.28)) {
            exitFade = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onFinished()
        }
    }

    private static func dayStamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

#Preview("Splash") {
    BrandSplashView(onFinished: {})
}
