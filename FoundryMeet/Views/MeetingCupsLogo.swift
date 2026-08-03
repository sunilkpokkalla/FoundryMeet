import SwiftUI

/// Pre-login loading: real app logo for 2 seconds, then hand off to Auth.
struct BrandSplashView: View {
    var onFinished: () -> Void

    @State private var visible = false

    var body: some View {
        ZStack {
            AppColors.surface.ignoresSafeArea()

            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .opacity(visible ? 1 : 0)
                .scaleEffect(visible ? 1 : 0.92)
                .accessibilityLabel("FoundryMeet")
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                visible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeIn(duration: 0.25)) {
                    visible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onFinished()
                }
            }
        }
    }
}

#Preview {
    BrandSplashView(onFinished: {})
}
