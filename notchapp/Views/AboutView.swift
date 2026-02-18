import SwiftUI

struct AboutView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App icon + name
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

            VStack(spacing: 4) {
                Text("NotchPrompt")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("A teleprompter hidden in your Mac's notch.\nInvisible during screen shares.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.horizontal, 32)

            // Credits
            VStack(spacing: 16) {
                Text("Built By")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(1.5)

                VStack(spacing: 6) {
                    Text("RaptrX")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                    Text("Digital product studio")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Link(destination: URL(string: "https://raptrx.com")!) {
                        Text("raptrx.com")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.accentPrimary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .frame(width: 80)

                VStack(spacing: 6) {
                    Text("Ali Arain")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                    Text("Developer & Founder")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Link(destination: URL(string: "https://aliarain.com")!) {
                        Text("aliarain.com")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.accentPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            VStack(spacing: 6) {
                Text("Made with ❤️ in Pakistan")
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
        .frame(width: 340, height: 480)
    }
}

#Preview {
    AboutView()
}
