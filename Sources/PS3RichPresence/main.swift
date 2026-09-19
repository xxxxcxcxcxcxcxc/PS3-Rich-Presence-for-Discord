import SwiftUI
import AppKit

private let fallbackClientID = "780389261870235650"

@main
struct PS3RichPresenceApp: App {
    @StateObject private var model = PresenceModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 860, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About PS3 Rich Presence") {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }
            }
        }
    }
}

@MainActor
final class PresenceModel: ObservableObject {
    @Published var ip = ""
    @Published var clientID = fallbackClientID
    @Published var interval = "35"
    @Published var showTemperature = true
    @Published var showElapsed = true
    @Published var retroCovers = false
    @Published var currentGame = "No game detected"
    @Published var currentTitleID = ""
    @Published var lastError = ""
    @Published var state: AppState = .ready
    @Published var logLines: [String] = []
    @Published var theme: AppTheme = .glass

    private var process: Process?
    private var outputPipe: Pipe?
    private var outputBuffer = ""
    private let defaults: [String: Any] = [
        "ip": "",
        "client_id": 780389261870235650,
        "wait_seconds": 35,
        "show_temp": true,
        "retro_covers": false,
        "show_elapsed": true,
        "hibernate_seconds": 600,
        "ip_prompt": false,
        "show_timer": true,
        "prefer_dev_app": false,
        "use_appname": false
    ]

    enum AppState: Equatable {
        case ready, checking, running, stopped, error(String)

        var title: String {
            switch self {
            case .ready: return "Ready"
            case .checking: return "Checking PS3"
            case .running: return "Presence active"
            case .stopped: return "Stopped"
            case .error: return "Needs attention"
            }
        }

        var color: Color {
            switch self {
            case .running: return .green
            case .checking: return .orange
            case .error: return .red
            default: return .secondary
            }
        }
    }

    enum AppTheme: String, CaseIterable, Identifiable {
        case glass = "Glass"
        case light = "Light"
        case dark = "Dark"

        var id: String { rawValue }
    }

    init() {
        loadConfig()
    }

    var isRunning: Bool { process?.isRunning == true }

    func start() {
        guard !isRunning else { return }
        guard !ip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state = .error("Enter the PS3 address")
            return
        }
        guard let seconds = Int(interval), seconds >= 15, Int64(clientID) != nil else {
            state = .error("Check application ID and interval")
            return
        }
        saveConfig()
        let bundledRoot = Bundle.main.resourceURL
        let sourceRoot = bundledRoot.map { root in
            FileManager.default.fileExists(atPath: root.appendingPathComponent("bootstrap.py").path)
                ? root
                : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        } ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dataRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PS3 Rich Presence", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true)
        let bootstrapScript = sourceRoot.appendingPathComponent("bootstrap.py")
        let workerScript = sourceRoot.appendingPathComponent("PS3RPD.py")
        let venvPython = dataRoot.appendingPathComponent(".venv/bin/python")
        let task = Process()
        if FileManager.default.isExecutableFile(atPath: venvPython.path) {
            task.executableURL = venvPython
            task.arguments = ["-u", workerScript.path]
        } else {
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["python3", bootstrapScript.path]
        }
        task.currentDirectoryURL = dataRoot
        var environment = ProcessInfo.processInfo.environment
        environment["PS3RPD_SOURCE_DIR"] = sourceRoot.path
        environment["PS3RPD_DATA_DIR"] = dataRoot.path
        task.environment = environment
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.consumeOutput(text)
                self?.logLines = Array((self?.logLines ?? []).suffix(300))
            }
        }
        task.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                if self?.lastError.isEmpty == true {
                    self?.state = .stopped
                }
                self?.process = nil
            }
        }
        do {
            try task.run()
            process = task
            outputPipe = pipe
            state = .running
            logLines.append("Starting PS3 Rich Presence worker...")
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        state = .stopped
    }

    private func consumeOutput(_ text: String) {
        outputBuffer += text
        let parts = outputBuffer.components(separatedBy: "\n")
        outputBuffer = parts.last ?? ""
        for line in parts.dropLast() {
            if line.hasPrefix("PS3RPD_STATUS:"),
               let data = line.dropFirst("PS3RPD_STATUS:".count).data(using: .utf8),
               let status = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                currentGame = status["game"] as? String ?? "No game detected"
                currentTitleID = status["title_id"] as? String ?? ""
            }
            if line.hasPrefix("PS3RPD_ERROR:") {
                lastError = String(line.dropFirst("PS3RPD_ERROR:".count)).trimmingCharacters(in: .whitespaces)
                state = .error(lastError)
            }
            logLines.append(line)
        }
    }

    func testPS3() {
        guard let url = URL(string: "http://\(ip)/") else {
            state = .error("Invalid PS3 address")
            return
        }
        state = .checking
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            Task { @MainActor in
                if let error {
                    self?.state = .error(error.localizedDescription)
                } else if body.localizedCaseInsensitiveContains("webman") || body.localizedCaseInsensitiveContains("wman") {
                    self?.state = .ready
                    self?.logLines.append("webMAN is responding at \(self?.ip ?? "PS3")")
                } else {
                    self?.state = .error("A page responded, but webMAN was not detected")
                }
            }
        }.resume()
    }

    private func configURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PS3 Rich Presence/ps3rpdconfig.txt")
    }

    private func loadConfig() {
        guard let data = try? Data(contentsOf: configURL()),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        ip = object["ip"] as? String ?? ip
        clientID = String(object["client_id"] as? Int ?? Int(fallbackClientID)!)
        interval = String(object["wait_seconds"] as? Int ?? 35)
        showTemperature = object["show_temp"] as? Bool ?? true
        showElapsed = object["show_elapsed"] as? Bool ?? true
        retroCovers = object["retro_covers"] as? Bool ?? false
    }

    private func saveConfig() {
        var config = defaults
        config["ip"] = ip
        config["client_id"] = Int(clientID) ?? Int(fallbackClientID)!
        config["wait_seconds"] = max(15, Int(interval) ?? 35)
        config["show_temp"] = showTemperature
        config["show_elapsed"] = showElapsed
        config["retro_covers"] = retroCovers
        let url = configURL()
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted]) {
            try? data.write(to: url)
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: PresenceModel
    @State private var selectedTab = "Overview"

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()
            if model.theme == .glass {
                Circle().fill(.blue.opacity(0.18)).frame(width: 320).blur(radius: 60).offset(x: -320, y: -230)
                Circle().fill(.pink.opacity(0.14)).frame(width: 280).blur(radius: 70).offset(x: 350, y: 260)
            }
            VStack(spacing: 0) {
                header
                HStack(spacing: 22) {
                    sidebar
                    ScrollView { mainContent }
                }
                .padding(24)
            }
        }
        .preferredColorScheme(model.theme == .light ? .light : .dark)
    }

    private var background: some View {
        switch model.theme {
        case .light:
            return AnyView(Color(red: 0.93, green: 0.95, blue: 0.98))
        case .dark:
            return AnyView(Color(red: 0.035, green: 0.045, blue: 0.065))
        case .glass:
            return AnyView(LinearGradient(colors: [Color(red: 0.05, green: 0.08, blue: 0.14), Color(red: 0.12, green: 0.08, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "gamecontroller.fill").font(.title2).foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 1) {
                Text("PS3 Rich Presence").font(.headline)
                Text("Discord activity bridge").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Theme", selection: $model.theme) {
                ForEach(PresenceModel.AppTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            StatusPill(state: model.state)
            Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WORKSPACE").font(.caption2.weight(.bold)).foregroundStyle(.secondary).padding(.horizontal, 12)
            SidebarButton(title: "Overview", icon: "rectangle.3.group.fill", selected: selectedTab == "Overview") { selectedTab = "Overview" }
            SidebarButton(title: "Connection", icon: "antenna.radiowaves.left.and.right", selected: selectedTab == "Connection") { selectedTab = "Connection" }
            Spacer()
            Label("macOS 15+", systemImage: "apple.logo").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
        }
        .frame(width: 160, alignment: .leading)
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedTab).font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Control your PlayStation 3 presence from this Mac.").foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.isRunning ? model.stop() : model.start() } label: {
                    Label(model.isRunning ? "Stop Presence" : "Start Presence", systemImage: model.isRunning ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent).tint(model.isRunning ? .red : .cyan)
            }
            if selectedTab == "Overview" {
                GlassCard {
                    HStack(spacing: 14) {
                        Image(systemName: "gamecontroller.fill").font(.system(size: 28)).foregroundStyle(.cyan)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Now playing").font(.caption).foregroundStyle(.secondary)
                            Text(model.currentGame).font(.title2.weight(.semibold))
                            if !model.currentTitleID.isEmpty {
                                Text(model.currentTitleID).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
                HStack(spacing: 14) {
                    MetricCard(title: "PS3", value: model.ip.isEmpty ? "Not configured" : model.ip, icon: "gamecontroller.fill", tint: .blue)
                    MetricCard(title: "Discord", value: model.lastError.isEmpty ? (model.isRunning ? "Connected" : "Waiting") : "Invalid ID", icon: "bubble.left.and.bubble.right.fill", tint: .indigo)
                    MetricCard(title: "Refresh", value: "Every \(model.interval)s", icon: "timer", tint: .orange)
                }
                logCard
            } else {
                connectionCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectionCard: some View {
        GlassCard {
            HStack {
                Label("Connection settings", systemImage: "slider.horizontal.3").font(.headline)
                Spacer()
                Button("Test PS3") { model.testPS3() }.buttonStyle(.bordered)
            }
            Divider().opacity(0.4)
            HStack(spacing: 14) {
                LabeledField(title: "PS3 IP address", text: $model.ip, placeholder: "192.168.1.42")
                LabeledField(title: "Discord app ID", text: $model.clientID, placeholder: fallbackClientID)
                LabeledField(title: "Refresh seconds", text: $model.interval, placeholder: "35")
            }
            Text("This activity appears on your personal Discord account through the open Discord app. No bot account or bot token is used.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 20) {
                Toggle("Temperature", isOn: $model.showTemperature)
                Toggle("Elapsed time", isOn: $model.showElapsed)
                Toggle("Retro covers", isOn: $model.retroCovers)
            }.toggleStyle(.switch).font(.subheadline)
        }
    }

    private var logCard: some View {
        GlassCard {
            HStack {
                Label("Activity", systemImage: "waveform.path.ecg").font(.headline)
                Spacer()
                Text("Live").font(.caption).foregroundStyle(.secondary)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(model.logLines.enumerated()), id: \.offset) { index, line in
                            Text(line).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).id(index)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 125, maxHeight: 180)
                .onChange(of: model.logLines.count) { _, _ in
                    if let last = model.logLines.indices.last { proxy.scrollTo(last) }
                }
            }
        }
    }

}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(18).liquidGlass(cornerRadius: 20)
    }
}

extension View {
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(.white.opacity(0.12)))
        }
#else
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(.white.opacity(0.12)))
#endif
    }
}

struct MetricCard: View {
    let title: String; let value: String; let icon: String; let tint: Color
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).foregroundStyle(tint).font(.title3)
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline).lineLimit(1).minimumScaleFactor(0.75)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LabeledField: View {
    let title: String; @Binding var text: String; let placeholder: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: $text).textFieldStyle(.roundedBorder)
        }.frame(maxWidth: .infinity)
    }
}

struct StatusPill: View {
    let state: PresenceModel.AppState
    var body: some View {
        HStack(spacing: 6) { Circle().fill(state.color).frame(width: 7, height: 7); Text(state.title) }
            .font(.caption.weight(.medium)).padding(.horizontal, 11).padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}

struct SidebarButton: View {
    let title: String; let icon: String; let selected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading) }
            .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 9)
            .background(selected ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(selected ? .primary : .secondary)
    }
}
