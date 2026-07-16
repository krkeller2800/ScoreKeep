import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ScoreKeepPhysicalMigrationTestOverlay: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @State private var protectedDataState: ScoreKeepProtectedDataObservationState = Self.initialProtectedDataState()
    @State private var baseline: ScoreKeepMigrationBaselineRecord?
    @State private var captureMessage = "Baseline not captured"
    @State private var copyConfirmationMessage = "Copy Summary"
    @State private var isExpanded = false

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            VStack(spacing: 8) {
                banner
                if isExpanded {
                    diagnosticsPanel
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .onAppear {
            refreshBaselineState()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            protectedDataState = .becameAvailable
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            protectedDataState = .willBecomeUnavailable
        }
    }

    private var banner: some View {
        let mode = ScoreKeepPhysicalMigrationTestMode.compiledMode
        return HStack(spacing: 10) {
            Circle()
                .fill(mode == .legacyStore ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text("ScoreKeep Migration Test")
                .font(.headline)
            Text(mode.displayTitle)
                .font(.subheadline.weight(.semibold))
            Text("Disposable Test Data Only")
                .font(.caption.weight(.semibold))
            Spacer()
            Button(isExpanded ? "Hide" : "Details") {
                isExpanded.toggle()
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(Color.red.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("ScoreKeepMigrationTestBanner")
    }

    private var diagnosticsPanel: some View {
        let diagnostics = ScoreKeepPhysicalDeviceDiagnostics.current(
            protectedDataState: protectedDataState,
            baselineStatus: baseline?.status ?? captureMessage
        )
        return VStack(alignment: .leading, spacing: 8) {
            Text("Mode: \(diagnostics.mode.displayTitle)")
            Text("Bundle: \(diagnostics.bundleIdentityClassification)")
            Text("Store: \(diagnostics.storeRole) / \(diagnostics.storeFileName)")
            Text("Family: \(diagnostics.storeFamilyMembersPresent.joined(separator: ", "))")
            Text("Protected Data: \(diagnostics.protectedDataState.rawValue)")
            Text("Journal: \(diagnostics.migrationJournalPresence), Backup: \(diagnostics.verifiedBackupPresence)")
            Text("Migration: \(diagnostics.migrationPhase), Writes: \(diagnostics.proposedWriteReadiness)")
            Text("Capacity: \(diagnostics.capacityDiagnostic)")
            Text("Baseline: \(baseline?.status ?? captureMessage)")
            if let baseline {
                Text(baseline.summary)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            HStack {
                Button("Capture Migration Baseline") {
                    captureBaseline()
                }
                .buttonStyle(.borderedProminent)
                .disabled(ScoreKeepPhysicalMigrationTestMode.compiledMode != .legacyStore)

                Button(copyConfirmationMessage) {
                    copySummary(diagnostics: diagnostics)
                }
                .buttonStyle(.bordered)
            }
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("ScoreKeepMigrationTestDiagnostics")
    }

    private func captureBaseline() {
        do {
            let record = try ScoreKeepMigrationBaselineCapture.capture(modelContext: modelContext)
            baseline = record
            captureMessage = record.status
        } catch {
            captureMessage = "Capture failed: \(String(describing: error).prefix(80))"
        }
    }

    private func copySummary(diagnostics: ScoreKeepPhysicalDeviceDiagnostics) {
        let baselineSummary = baseline.map { "\n\n" + $0.summary } ?? ""
        UIPasteboard.general.string = diagnostics.copyableSummary + baselineSummary
        copyConfirmationMessage = "✓ Copied"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copyConfirmationMessage = "Copy Summary"
        }
    }

    private func refreshBaselineState() {
        let result = ScoreKeepMigrationBaselineCapture.loadResult()
        baseline = result.record
        captureMessage = result.statusMessage
    }

    private static func initialProtectedDataState() -> ScoreKeepProtectedDataObservationState {
        #if canImport(UIKit)
        return UIApplication.shared.isProtectedDataAvailable ? .available : .unavailable
        #else
        return .unknownOrUnsupported
        #endif
    }
}
