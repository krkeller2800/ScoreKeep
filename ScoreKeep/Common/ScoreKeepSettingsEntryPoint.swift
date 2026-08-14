import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ScoreKeepSettingsView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let onOpenImportFlow: () -> Void
    let onOpenExportFlow: () -> Void
    let onOpenHelp: () -> Void

    @AppStorage("scoreKeepAppearance") private var appearanceSelection = ScoreKeepAppearanceOption.system.rawValue
    @State private var isShowingPaywall = false
    @State private var didCopyDiagnostics = false

    private let privacyURL = URL(string: "https://komakode.com/Privacy%20Policy")!
    private let supportEmailAddress = "comment@KomaKode.com"
    private let supportEmailSubject = "ScoreKeep Support"

    init(
        onOpenImportFlow: @escaping () -> Void = {},
        onOpenExportFlow: @escaping () -> Void = {},
        onOpenHelp: @escaping () -> Void = {}
    ) {
        self.onOpenImportFlow = onOpenImportFlow
        self.onOpenExportFlow = onOpenExportFlow
        self.onOpenHelp = onOpenHelp
    }

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                seasonPassSection
                dataSection
                helpSection
                aboutSection
                debugSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(context: .general)
                .environmentObject(purchaseManager)
        }
        .task {
            if purchaseManager.priceState == .notStarted {
                await purchaseManager.loadProducts()
            }
            await purchaseManager.refreshEntitlements()
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("App appearance", selection: $appearanceSelection) {
                ForEach(ScoreKeepAppearanceOption.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Applies across ScoreKeep and follows the system setting when System is selected.")
        }
    }

    private var seasonPassSection: some View {
        Section("Season Pass") {
            LabeledContent("Status", value: entitlementStatusText)

            Button(seasonPassActionTitle) {
                if purchaseManager.isSeasonPassActive {
                    Task { await purchaseManager.manageSubscriptions() }
                } else {
                    isShowingPaywall = true
                }
            }

            Button("Restore Purchases") {
                Task { await purchaseManager.restorePurchases() }
            }
            .disabled(purchaseManager.isPurchasing)

            if purchaseManager.isPurchasing {
                HStack {
                    ProgressView()
                    Text("Checking purchase status")
                }
            }

            if let lastErrorMessage = purchaseManager.lastErrorMessage, !lastErrorMessage.isEmpty {
                Text(lastErrorMessage)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button("Import Data") {
                routeOut(to: onOpenImportFlow)
            }

            Button("Export or Share Data") {
                routeOut(to: onOpenExportFlow)
            }
        }
    }

    private var helpSection: some View {
        Section("Help") {
            Button("Help Documentation") {
                routeOut(to: onOpenHelp)
            }

            Button("Contact Support") {
                openURL(supportURL)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "\(appVersion) (\(buildNumber))")
            LabeledContent("Developer", value: "KomaKode")

            Link("Privacy Policy", destination: privacyURL)

            NavigationLink("Acknowledgements") {
                Form {
                    Section("Acknowledgements") {
                        LabeledContent("Designers", value: "Karl Keller")
                        LabeledContent("Coding Assistants", value: "Codex • Gemini • Claude")
                    }
                }
                .navigationTitle("Acknowledgements")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    @ViewBuilder
    private var debugSection: some View {
        #if DEBUG
        Section("Debug") {
            LabeledContent("Build Configuration", value: "DEBUG")
            LabeledContent("App Version", value: "\(appVersion) (\(buildNumber))")
            LabeledContent("Season Pass Status", value: entitlementStatusText)
            LabeledContent("Raw Entitlement State", value: rawEntitlementStateText)
            LabeledContent("Store Product Lookup", value: productStatusText)

            Button("Copy Support Information") {
                copyDiagnostics()
            }

            if didCopyDiagnostics {
                Text("Debug diagnostics copied.")
                    .foregroundStyle(.secondary)
            }
        }
        #endif
    }

    private var seasonPassActionTitle: String {
        purchaseManager.isSeasonPassActive ? "Manage" : "Upgrade"
    }

    private var entitlementStatusText: String {
        switch purchaseManager.entitlementState {
        case .entitled:
            return "Purchased"
        case .notEntitled, .statusUnavailable:
            return "Not Purchased"
        case .priorSeason:
            return "Expired Prior Season"
        case .futureSeason:
            return "Future Season Pass Found"
        }
    }

    private var rawEntitlementStateText: String {
        switch purchaseManager.entitlementState {
        case .entitled:
            return "entitled"
        case .notEntitled:
            return "notEntitled"
        case .priorSeason:
            return "priorSeason"
        case .futureSeason:
            return "futureSeason"
        case .statusUnavailable:
            return "statusUnavailable"
        }
    }

    private var productStatusText: String {
        switch purchaseManager.priceState {
        case .notStarted:
            return "Not Loaded"
        case .loading:
            return "Loading"
        case .discovered(let product):
            return product.displayPrice
        case .productUnavailable:
            return "Unavailable"
        case .failure:
            return "Failed"
        }
    }

    private var supportURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmailAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: supportEmailSubject),
            URLQueryItem(name: "body", value: supportEmailBody)
        ]

        return components.url ?? URL(string: "mailto:\(supportEmailAddress)")!
    }

    private var supportEmailBody: String {
        """
        Please describe the problem above this line.

        ---
        Support Information
        \(supportInformation)
        """
    }

    private var supportInformation: String {
        [
            "App: \(appName)",
            "Version: \(appVersion) (\(buildNumber))",
            "Device Model: \(deviceModel)",
            "iOS Version: \(operatingSystemVersion)",
            "Appearance: \(currentAppearanceTitle)",
            "Season Pass Status: \(entitlementStatusText)",
            "Store Product Lookup: \(productStatusText)"
        ].joined(separator: "\n")
    }

    private var currentAppearanceTitle: String {
        ScoreKeepAppearanceOption(rawValue: appearanceSelection)?.title ?? ScoreKeepAppearanceOption.system.title
    }

    private var deviceModel: String {
        #if canImport(UIKit)
        UIDevice.current.model
        #else
        "Unknown"
        #endif
    }

    private var operatingSystemVersion: String {
        #if canImport(UIKit)
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        "Unknown"
        #endif
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "ScoreKeep"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }

    private func routeOut(to action: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.async {
            action()
        }
    }

    private func copyDiagnostics() {
        #if canImport(UIKit)
        UIPasteboard.general.string = supportEmailBody
        #endif
        didCopyDiagnostics = true
    }
}

enum ScoreKeepAppearanceOption: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct ScoreKeepSettingsGearButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isShowingSettings: Bool

    var body: some View {
        Button {
            isShowingSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ScoreKeepVisualStyle.accent)
                .frame(width: 44, height: 44)
                .background(gearBackground, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(gearOutline, lineWidth: 1)
                }
                .shadow(color: gearShadow, radius: 3, x: 0, y: 1)
        }
        .accessibilityLabel("Settings")
    }

    private var gearBackground: Color {
        colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white
    }

    private var gearOutline: Color {
        colorScheme == .dark ? .white.opacity(0.18) : .gray.opacity(0.35)
    }

    private var gearShadow: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .black.opacity(0.12)
    }
}

private struct ScoreKeepPhoneSettingsEntryPointModifier: ViewModifier {
    @State private var isShowingSettings = false

    let onOpenImportFlow: () -> Void
    let onOpenExportFlow: () -> Void
    let onOpenHelp: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                GeometryReader { geometry in
                    ScoreKeepSettingsGearButton(isShowingSettings: $isShowingSettings)
                        .position(
                            x: geometry.size.width - phoneSettingsTrailingPadding(for: geometry.size.width) - 22,
                            y: geometry.size.height - 42
                        )
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .sheet(isPresented: $isShowingSettings) {
                ScoreKeepSettingsView(
                    onOpenImportFlow: onOpenImportFlow,
                    onOpenExportFlow: onOpenExportFlow,
                    onOpenHelp: onOpenHelp
                )
            }
    }

    private func phoneSettingsTrailingPadding(for width: CGFloat) -> CGFloat {
        max(16, min(190, (width - 560) / 2))
    }
}

extension View {
    func scoreKeepPhoneSettingsEntryPoint(
        onOpenImportFlow: @escaping () -> Void = {},
        onOpenExportFlow: @escaping () -> Void = {},
        onOpenHelp: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            ScoreKeepPhoneSettingsEntryPointModifier(
                onOpenImportFlow: onOpenImportFlow,
                onOpenExportFlow: onOpenExportFlow,
                onOpenHelp: onOpenHelp
            )
        )
    }
}
