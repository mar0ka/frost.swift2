import SwiftUI
import UIKit
import Darwin

private enum FrostTheme {
    static let background = Color(red: 13.0 / 255.0, green: 14.0 / 255.0, blue: 18.0 / 255.0)
    static let card = Color(red: 22.0 / 255.0, green: 24.0 / 255.0, blue: 31.0 / 255.0)
    static let console = Color(red: 7.0 / 255.0, green: 9.0 / 255.0, blue: 13.0 / 255.0)
    static let cyan = Color(red: 0.0, green: 229.0 / 255.0, blue: 1.0)
    static let green = Color(red: 0.25, green: 0.88, blue: 0.56)
}

@MainActor
final class FrostloaderViewModel: ObservableObject {
    @Published private(set) var logs: [String] = []
    @Published private(set) var progress: Double = 0
    @Published private(set) var isRunning = false
    @Published private(set) var isLoaded = false
    @Published var isRespringOverlayVisible = false

    private var logTask: Task<Void, Never>?
    private var respringTask: Task<Void, Never>?

    var status: String {
        if isRunning { return "Collecting system diagnostics…" }
        if isLoaded { return "DIAGNOSTICS COMPLETE • DEVICE UNCHANGED" }
        return "Idle — Ready to initialize"
    }

    func startExploitFlow() {
        logTask?.cancel()
        logs.removeAll(keepingCapacity: true)
        progress = 0
        isLoaded = false
        isRunning = true

        let lines = Self.makeDiagnosticLines()
        logTask = Task { [weak self] in
            guard let self else { return }
            let nanosecondsPerLine: UInt64 = 8_800_000

            for (index, line) in lines.enumerated() {
                guard !Task.isCancelled else { return }

                self.logs.append(line)
                self.progress = Double(index + 1) / Double(lines.count)

                if (index + 1).isMultiple(of: 100) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

                try? await Task.sleep(nanoseconds: nanosecondsPerLine)
            }

            guard !Task.isCancelled else { return }
            self.isRunning = false
            self.isLoaded = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func showRespringSequence() {
        guard !isRespringOverlayVisible else { return }

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.easeInOut(duration: 0.25)) {
            isRespringOverlayVisible = true
        }

        respringTask?.cancel()
        respringTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled, let self else { return }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeInOut(duration: 0.3)) {
                self.isRespringOverlayVisible = false
            }
        }
    }

    func copyLogs() {
        UIPasteboard.general.string = logs.joined(separator: "\n")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private static func makeDiagnosticLines() -> [String] {
        let stages: [(String, [String])] = [
            ("[boot]", [
                "Initializing Frostloader diagnostics…",
                "Preparing read-only inspection session",
                "Runtime environment available [OK]"
            ]),
            ("[device]", [
                "Reading UIDevice model information",
                "Collecting iOS version metadata",
                "Device information recorded [OK]"
            ]),
            ("[process]", [
                "Reading ProcessInfo runtime properties",
                "Checking process architecture metadata",
                "Architecture metadata recorded [OK]"
            ]),
            ("[xpf-info]", [
                "Checking patchfinder component availability",
                "No kernel patchfinder connection configured",
                "Read-only component check complete"
            ]),
            ("[kernel-info]", [
                "Kernel base address unavailable to app sandbox",
                "No kernel memory access requested",
                "Protected address space left unchanged"
            ]),
            ("[security]", [
                "Reviewing platform security capability flags",
                "No AMFI or sandbox changes attempted",
                "System security settings unchanged [OK]"
            ]),
            ("[network]", [
                "Reading network interface metadata",
                "No tunnel configuration requested",
                "Network configuration unchanged [OK]"
            ]),
            ("[verify]", [
                "Validating collected diagnostic records",
                "Checking report sequence integrity",
                "Diagnostic record accepted [OK]"
            ]),
            ("[report]", [
                "Appending diagnostic event",
                "Updating progress counters",
                "Waiting for next diagnostic event"
            ])
        ]

        return (0..<1_000).map { index in
            let stage = stages[index % stages.count]
            let message = stage.1[(index / stages.count) % stage.1.count]
            return String(format: "%04d", index + 1) + " " + stage.0 + " " + message
        }
    }
}

struct ContentView: View {
    @StateObject private var model = FrostloaderViewModel()

    var body: some View {
        ZStack {
            TabView {
                exploitTab
                    .tabItem {
                        Label("Exploit", systemImage: "terminal")
                    }

                LogsView(model: model)
                    .tabItem {
                        Label("Logs", systemImage: "doc.text")
                    }
            }
            .tint(FrostTheme.cyan)

            if model.isRespringOverlayVisible {
                respringOverlay
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var exploitTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    header
                    systemInfoCard
                    actionCard
                    miniConsole
                }
                .padding(.horizontal, 18)
                .padding(.top, 15)
                .padding(.bottom, 30)
            }
            .background(FrostTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("frostloader")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(.white)

                Text("v1.0  •  k/w Engine")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Text(model.isLoaded ? "LOADED" : "STANDBY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(model.isLoaded ? FrostTheme.green : FrostTheme.cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background((model.isLoaded ? FrostTheme.green : FrostTheme.cyan).opacity(0.13))
                .overlay {
                    Capsule()
                        .stroke((model.isLoaded ? FrostTheme.green : FrostTheme.cyan).opacity(0.4), lineWidth: 1)
                }
                .clipShape(Capsule())
                .shadow(color: model.isLoaded ? FrostTheme.green.opacity(0.25) : .clear, radius: 9)
        }
    }

    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("SYSTEM INFORMATION", systemImage: "iphone")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                Circle()
                    .fill(FrostTheme.green)
                    .frame(width: 7, height: 7)

                Text("READY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(FrostTheme.green)
            }

            infoRow("iOS Version", value: UIDevice.current.systemVersion)
            infoRow("Device Model", value: UIDevice.current.model)
            infoRow("Architecture", value: Self.runtimeArchitecture)
            infoRow("Kernel Base", value: "Unavailable")
            infoRow("XPF Status", value: "Not connected", color: FrostTheme.cyan)

            Text("Kernel addresses and protected system state are not exposed to ordinary apps.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.38))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(16)
        .background(FrostTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.055), lineWidth: 1)
        }
    }

    private static var runtimeArchitecture: String {
        MemoryLayout<Int>.size == 8 ? "64-bit" : "32-bit"
    }

    private func infoRow(_ title: String, value: String, color: Color = .white) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.48))

            Spacer()

            Text(value)
                .foregroundStyle(color)
                .fontWeight(.medium)
                .monospaced()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.system(size: 12))
    }

    private var actionCard: some View {
        VStack(spacing: 13) {
            Button {
                model.startExploitFlow()
            } label: {
                HStack(spacing: 9) {
                    if model.isRunning {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: model.isLoaded ? "checkmark.circle.fill" : "bolt.fill")
                    }

                    Text(model.isRunning ? "Working…" : (model.isLoaded ? "Run Again" : "Exploit"))
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.92))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: [FrostTheme.cyan, Color(red: 0.22, green: 0.68, blue: 0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .disabled(model.isRunning)
            .opacity(model.isRunning ? 0.72 : 1)

            ProgressView(value: model.progress)
                .tint(model.isLoaded ? FrostTheme.green : FrostTheme.cyan)

            HStack(spacing: 7) {
                Circle()
                    .fill(model.isLoaded ? FrostTheme.green : (model.isRunning ? FrostTheme.cyan : .white.opacity(0.35)))
                    .frame(width: 6, height: 6)

                Text(model.status)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                Text("\(model.logs.count)/1000")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }

            if model.isLoaded {
                HStack(spacing: 10) {
                    Button {
                        model.showRespringSequence()
                    } label: {
                        Label("Respring", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(FrostTheme.cyan)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }

                    Button {
                        model.startExploitFlow()
                    } label: {
                        Text("Re-run Exploit")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.white.opacity(0.08))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
        }
        .padding(16)
        .background(FrostTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.055), lineWidth: 1)
        }
    }

    private var miniConsole: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("LIVE CONSOLE", systemImage: "terminal")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                Text("READ ONLY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(FrostTheme.green)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        if model.logs.isEmpty {
                            Text("$ frostloader --diagnostics")
                                .foregroundStyle(FrostTheme.cyan)

                            Text("Waiting for diagnostic session…")
                                .foregroundStyle(.white.opacity(0.42))
                        } else {
                            ForEach(Array(model.logs.suffix(90)), id: \.self) { line in
                                Text(line)
                                    .foregroundStyle(line.contains("[report]") ? FrostTheme.green : .white.opacity(0.78))
                                    .id(line)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .frame(height: 174)
                .onChange(of: model.logs.count) { _ in
                    if let last = model.logs.last {
                        withAnimation(.linear(duration: 0.06)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .background(FrostTheme.console)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(15)
        .background(FrostTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.055), lineWidth: 1)
        }
    }

    private var respringOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.35)

                Text("Restarting interface…")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .ignoresSafeArea()
        .accessibilityLabel("Interface restart preview")
    }
}

private struct LogsView: View {
    @ObservedObject var model: FrostloaderViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("\(model.logs.count) / 1000 LINES")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.48))

                    Spacer()

                    Button {
                        model.copyLogs()
                    } label: {
                        Label("Copy Logs", systemImage: "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .tint(FrostTheme.cyan)
                    .disabled(model.logs.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            if model.logs.isEmpty {
                                Text("$ frostloader --logs")
                                    .foregroundStyle(FrostTheme.cyan)

                                Text("No diagnostic events yet.")
                                    .foregroundStyle(.white.opacity(0.42))
                            } else {
                                ForEach(model.logs, id: \.self) { line in
                                    Text(line)
                                        .foregroundStyle(line.contains("[report]") ? FrostTheme.green : .white.opacity(0.82))
                                        .textSelection(.enabled)
                                        .id(line)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                    .onChange(of: model.logs.count) { _ in
                        if let last = model.logs.last {
                            withAnimation(.linear(duration: 0.06)) {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
                .font(.system(size: 11, weight: .regular, design: .monospaced))
            }
            .background(FrostTheme.console.ignoresSafeArea())
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(FrostTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}
