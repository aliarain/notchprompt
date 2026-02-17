import SwiftUI

struct AboutView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(Theme.accentGradient)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .onAppear {
                            withAnimation(Theme.springAnimation) {
                                logoScale = 1.0
                                logoOpacity = 1.0
                            }
                        }

                    Text("NotchPrompt")
                        .font(.system(size: 22, weight: .bold, design: .rounded))

                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 16)

                Text("A teleprompter hidden in your Mac's notch.\nInvisible during screen shares.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .padding(.horizontal, 32)

                VStack(spacing: 20) {
                    Text("Built By")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(1.5)

                    VStack(spacing: 8) {
                        Text("RaptrX")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))

                        Text("Digital product studio building the future. From zero to Series A - lean products with just the right features for smooth performance and user love.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)

                        Link(destination: URL(string: "https://raptrx.com")!) {
                            Text("raptrx.com")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.accentPrimary)
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .frame(width: 100)

                    VStack(spacing: 8) {
                        Text("Ali Arain")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))

                        Text("Tech entrepreneur & full-stack developer from Pakistan. Founder of LiftUpAI. Building products, sharing lessons through podcasts, and exploring the intersection of AI and space.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)

                        Link(destination: URL(string: "https://aliarain.com")!) {
                            Text("aliarain.com")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.accentPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 20)

                VStack(spacing: 6) {
                    Text("Made with passion in Pakistan")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 16) {
                        Link(destination: URL(string: "https://github.com/aliarain")!) {
                            Image(systemName: "link")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Link(destination: URL(string: "https://twitter.com/realaliarain")!) {
                            Image(systemName: "at")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 340, height: 520)
    }
}

#Preview {
    AboutView()
}
