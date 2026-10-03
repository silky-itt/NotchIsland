import SwiftUI

/// Music block shown when expanded.
struct NowPlayingView: View {
    @Environment(NowPlayingMonitor.self) private var nowPlaying

    var body: some View {
        if !nowPlaying.isAvailable {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Now Playing", systemImage: "music.note")
                Placeholder(text: "mediaremote-adapter is not bundled in the app (see build.sh)")
            }
        } else if !nowPlaying.hasMedia {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Now Playing", systemImage: "music.note")
                Placeholder(text: "Nothing is playing")
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                ArtworkView(image: nowPlaying.artwork, size: 64, cornerRadius: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(nowPlaying.title ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(nowPlaying.artist ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)

                    if let name = nowPlaying.sourceName {
                        Button { nowPlaying.activateSource() } label: {
                            HStack(spacing: 4) {
                                if let icon = nowPlaying.sourceIcon { Image(nsImage: icon) }
                                Text(name).font(.system(size: 10)).lineLimit(1)
                            }
                            .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .help("Open \(name)")
                    }

                    Spacer(minLength: 4)
                    controls
                    if let duration = nowPlaying.duration {
                        ProgressRow(duration: duration)
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 18) {
            ControlButton(systemImage: "backward.fill", size: 13) { nowPlaying.send(.previousTrack) }
            ControlButton(systemImage: nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 17) {
                nowPlaying.send(.togglePlayPause)
            }
            ControlButton(systemImage: "forward.fill", size: 13) { nowPlaying.send(.nextTrack) }
        }
    }
}

/// Progress bar. TimelineView only runs while the expanded block is visible (it is destroyed when collapsed).
private struct ProgressRow: View {
    @Environment(NowPlayingMonitor.self) private var nowPlaying
    let duration: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = nowPlaying.elapsed(at: context.date)
            HStack(spacing: 6) {
                Text(Self.format(elapsed))
                GeometryReader { proxy in
                    Capsule().fill(.white.opacity(0.2))
                        .overlay(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.85))
                                .frame(width: proxy.size.width * min(max(elapsed / duration, 0), 1))
                        }
                }
                .frame(height: 3)
                Text(Self.format(duration))
            }
            .font(.system(size: 9).monospacedDigit())
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    private static func format(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct ControlButton: View {
    let systemImage: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size))
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white.opacity(0.12))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Small artwork + waveform on both sides of the notch while playing.
struct NowPlayingActivity {
    struct Leading: View {
        @Environment(NowPlayingMonitor.self) private var nowPlaying

        var body: some View {
            ArtworkView(image: nowPlaying.artwork, size: 20, cornerRadius: 5)
        }
    }

    struct Trailing: View {
        var body: some View {
            WaveformView(color: .systemGreen)
                .frame(width: 18, height: 14)
        }
    }
}
