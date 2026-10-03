import AppKit
import Darwin
import Observation

/// Reads the system "Now Playing" info (Spotify, YouTube in a browser...).
///
/// Since macOS 15.4, third-party apps can no longer call MediaRemote directly, so this uses
/// mediaremote-adapter: it runs `/usr/bin/perl` (which the system allows) to stream JSON to stdout.
/// The adapter must be inside the app bundle (see build.sh); without it `isAvailable == false`.
@Observable
@MainActor
final class NowPlayingMonitor {
    private(set) var isAvailable = false
    private(set) var isPlaying = false
    private(set) var title: String?
    private(set) var artist: String?
    private(set) var artwork: NSImage?
    private(set) var duration: Double?
    private(set) var bundleIdentifier: String?
    /// The app that is playing (Spotify, Google Chrome...), to show where the audio comes from
    private(set) var sourceName: String?
    private(set) var sourceIcon: NSImage?
    @ObservationIgnored private var elapsedTime: Double = 0
    @ObservationIgnored private var elapsedTimestamp: Date?
    @ObservationIgnored private var playbackRate: Double = 1

    var hasMedia: Bool { title?.isEmpty == false }

    enum Command: Int {
        case togglePlayPause = 2
        case nextTrack = 4
        case previousTrack = 5
    }

    @ObservationIgnored private let adapter: (script: String, framework: String)?
    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var payload: [String: Any] = [:]
    @ObservationIgnored private var lineBuffer = Data()
    @ObservationIgnored private var isStopping = false
    @ObservationIgnored private var restartDelay: TimeInterval = 1

    private static let dateFormatter = ISO8601DateFormatter()

    init() {
        if let script = Bundle.main.path(forResource: "mediaremote-adapter", ofType: "pl"),
           let frameworks = Bundle.main.privateFrameworksPath {
            let framework = (frameworks as NSString).appendingPathComponent("MediaRemoteAdapter.framework")
            adapter = FileManager.default.fileExists(atPath: framework) ? (script, framework) : nil
        } else {
            adapter = nil
        }
        isAvailable = adapter != nil
    }

    func start() {
        guard let adapter, process == nil else { return }
        isStopping = false

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        // --debounce merges the burst of updates when the track changes
        process.arguments = [adapter.script, adapter.framework, "stream", "--debounce=100"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in self?.receive(data) }
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.processDidExit() }
        }

        do {
            try process.run()
            self.process = process
        } catch {
            NSLog("NotchIsland: could not launch mediaremote-adapter: \(error)")
        }
    }

    func stop() {
        isStopping = true
        process?.terminate()
        process = nil
    }

    /// Brings the playing app to the front (for a browser, the browser itself; macOS does not say which tab).
    func activateSource() {
        guard let bundleIdentifier else { return }
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            app.activate()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    func send(_ command: Command) {
        guard let adapter else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [adapter.script, adapter.framework, "send", String(command.rawValue)]
        try? process.run()
    }

    /// Elapsed time at `date` (the adapter only reports on state changes; the rest is computed).
    func elapsed(at date: Date) -> Double {
        guard isPlaying, let elapsedTimestamp else { return elapsedTime }
        let value = elapsedTime + date.timeIntervalSince(elapsedTimestamp) * playbackRate
        return min(value, duration ?? value)
    }

    // MARK: - Reading the stream

    private func processDidExit() {
        process?.standardOutput.flatMap { ($0 as? Pipe)?.fileHandleForReading.readabilityHandler = nil }
        process = nil
        guard !isStopping else { return }
        // Adapter died unexpectedly -> restart with growing delay so a broken adapter is not spammed
        DispatchQueue.main.asyncAfter(deadline: .now() + restartDelay) { [weak self] in
            MainActor.assumeIsolated { self?.start() }
        }
        restartDelay = min(restartDelay * 2, 60)
    }

    private func receive(_ data: Data) {
        lineBuffer.append(data)
        while let newline = lineBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = Data(lineBuffer[lineBuffer.startIndex..<newline])
            lineBuffer.removeSubrange(lineBuffer.startIndex...newline)
            handle(line: line)
        }
        // Data keeps its capacity after removeSubrange; a line with artwork is hundreds of KB, so let go of it
        if lineBuffer.isEmpty { lineBuffer = Data() }
    }

    private func handle(line: Data) {
        let hadArtwork = autoreleasepool { process(line: line) }
        // Cover art leaves freed-but-dirty pages behind in the allocator; hand them back
        if hadArtwork { malloc_zone_pressure_relief(nil, 0) }
    }

    /// Returns true if the line carried cover art.
    private func process(line: Data) -> Bool {
        // The cover is cut out of the raw bytes first (see ArtworkPayload), so the JSON parser only sees a small line
        let (json, image) = ArtworkPayload.split(line)
        guard let message = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let update = message["payload"] as? [String: Any]
        else { return false }
        restartDelay = 1

        let isDiff = message["diff"] as? Bool ?? false
        if !isDiff { payload = [:] }
        for (key, value) in update where key != "artworkData" {
            if value is NSNull { payload.removeValue(forKey: key) } else { payload[key] = value }
        }

        // Artwork is only sent on change -> downscale once, do not keep the original data
        let hasArtwork = update["artworkData"] != nil
        if hasArtwork {
            artwork = image.flatMap { ArtworkPayload.thumbnail(from: $0) }
        } else if !isDiff {
            artwork = nil
        }
        apply()
        return hasArtwork && image != nil
    }

    private func apply() {
        title = payload["title"] as? String
        artist = payload["artist"] as? String
        isPlaying = payload["playing"] as? Bool ?? false
        // For a child app (e.g. a web app) use the parent app to show the browser name/icon
        let source = (payload["parentApplicationBundleIdentifier"] as? String) ?? (payload["bundleIdentifier"] as? String)
        if source != bundleIdentifier { updateSource(source) }
        let duration = payload["duration"] as? Double
        self.duration = duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        elapsedTime = payload["elapsedTime"] as? Double ?? 0
        elapsedTimestamp = (payload["timestamp"] as? String).flatMap(Self.dateFormatter.date(from:))
        playbackRate = payload["playbackRate"] as? Double ?? 1
    }

    private func updateSource(_ identifier: String?) {
        bundleIdentifier = identifier
        guard let identifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            sourceName = nil
            sourceIcon = nil
            return
        }
        sourceName = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 14, height: 14)
        sourceIcon = icon
    }

}
