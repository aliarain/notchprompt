import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App Icon and Name
            VStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.primary)

                Text("NotchPrompt")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            // Description
            Text("A teleprompter hidden in your Mac's notch.\nInvisible during screen shares.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .padding(.horizontal, 32)

            // Creators
            VStack(spacing: 16) {
                Text("Built By")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(1)

                // RaptrX
                VStack(spacing: 8) {
                    Text("RaptrX")
                        .font(.system(size: 15, weight: .semibold))

                    Text("Digital product studio building the future. From zero to Series A - lean products with just the right features for smooth performance and user love.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 24)

                    Link(destination: URL(string: "https://raptrx.com")!) {
                        Text("raptrx.com")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .frame(width: 100)

                // Ali Arain
                VStack(spacing: 8) {
                    Text("Ali Arain")
                        .font(.system(size: 15, weight: .semibold))

                    Text("Tech entrepreneur & full-stack developer from Pakistan. Founder of LiftUpAI. Building products, sharing lessons through podcasts, and exploring the intersection of AI and space.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 24)

                    Link(destination: URL(string: "https://aliarain.com")!) {
                        Text("aliarain.com")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Footer
            VStack(spacing: 4) {
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
            .padding(.bottom, 12)
        }
        .frame(width: 320, height: 460)
    }
}

#Preview {
    AboutView()
}
