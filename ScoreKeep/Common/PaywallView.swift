//
//  PaywallView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 11/24/25.
//

import SwiftUI
import StoreKit

enum PaywallContext {
    case general
    case gameLimit
    case downloadLimit
    case reports

    var message: String? {
        switch self {
        case .general:
            return nil
        case .gameLimit:
            return "Score unlimited games this season."
        case .downloadLimit:
            return "Download unlimited team rosters."
        case .reports:
            return "Create PDF reports for coaches and parents."
        }
    }
}

struct PaywallView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let context: PaywallContext

    init(context: PaywallContext = .general) {
        self.context = context
    }

    // These will be driven by the loaded product's year
    private var productYear: String {

        if let id = purchaseManager.seasonPassProduct?.id, id.count >= 4 {
            return String(id.suffix(4))
        }
        // Fallback to current year if product not yet loaded
        let yr = Calendar.current.component(.year, from: Date())
        return String(yr)
    }

    private var dynamicTitle: String {
        "ScoreKeep \(productYear) Season Pass"
    }

    private var dynamicSubtitle: String {
        "Unlimited Downloads and Scoring Games Through \(productYear)"
    }

    var benefits: [String] = [
        "Score every game this season",
        "Track full team and player stats",
        "Export coach-ready PDF reports",
        "Import MLB/team rosters without limits"
    ]

    private let privacyURL = URL(string: "https://komakode.com/Privacy%20Policy")!
    private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    @State private var showingError: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if UIDevice.type == "iPhone" {
                    GeometryReader { proxy in
                        let h = proxy.size.height
                        let extraCompact = h < 720

                        VStack(spacing: extraCompact ? 10 : 14) {
                            header(compact: true, extraCompact: extraCompact, showInlineTitle: false)
                            priceAndCTA(compact: true, extraCompact: extraCompact)

                            // Non-renewing: no manage UI
                            benefitsGrid(compact: true, extraCompact: extraCompact)
                            legalLinks(compact: true, extraCompact: extraCompact)
                        }
                        .padding(.horizontal, extraCompact ? 12 : 16)
                        .padding(.top, extraCompact ? 8 : 12)
                        .padding(.bottom, extraCompact ? 8 : 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background(Color(.systemBackground))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            header(compact: false, extraCompact: false, showInlineTitle: false)
                            priceAndCTA(compact: false, extraCompact: false)
                            // Non-renewing: no manage UI
                            benefitsList
                            legalLinks(compact: false, extraCompact: false)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationTitle(UIDevice.type == "iPhone" ? "Upgrade" : "Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(purchaseManager.$isSeasonPassActive) { _ in
                // Keep open; user may want to read benefits; or dismiss automatically if you prefer
            }
            .onChange(of: purchaseManager.lastErrorMessage) {
                showingError = (purchaseManager.lastErrorMessage?.isEmpty == false)
            }
            .alert(purchaseManager.lastErrorMessage ?? "", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            }
        }
        .task {
            if scenePhase == .active {
                if case .discovered = purchaseManager.priceState { } else {
                    await purchaseManager.loadProducts()
                }
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                if case .discovered = purchaseManager.priceState { } else {
                    Task { await purchaseManager.loadProducts() }
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func header(compact: Bool, extraCompact: Bool, showInlineTitle: Bool = false) -> some View {
        VStack(spacing: compact ? (extraCompact ? 4 : 6) : 8) {
            Image(systemName: "ticket.fill")
                .font(.system(size: compact ? (extraCompact ? 32 : 36) : 48))
                .foregroundStyle(.blue)

            Text(dynamicTitle)
                .font(compact ? (extraCompact ? .headline.bold() : .title3.bold()) : .title2.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(dynamicSubtitle)
                .font(compact ? (extraCompact ? .footnote : .subheadline) : .body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(compact ? 1 : 2)
                .minimumScaleFactor(0.8)

            if let message = context.message {
                Text(message)
                    .font(compact ? (extraCompact ? .subheadline.bold() : .headline.bold()) : .title3.bold())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.top, compact ? 2 : 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func priceAndCTA(compact: Bool, extraCompact: Bool) -> some View {
        VStack(spacing: compact ? (extraCompact ? 8 : 10) : 12) {
            switch purchaseManager.priceState {
            case .discovered(let product):
                Text(product.displayPrice)
                    .font(compact ? (extraCompact ? .title3.bold() : .title2.bold()) : .largeTitle.bold())
                    .accessibilityLabel("Price \(product.displayPrice)")
            case .loading, .notStarted:
                ProgressView().progressViewStyle(.circular)
            case .productUnavailable, .failure:
                Text("Price Unavailable")
                    .font(compact ? (extraCompact ? .title3.bold() : .title2.bold()) : .largeTitle.bold())
                    .foregroundColor(.secondary)
            }

            Button {
                Task {
                    if case .discovered = purchaseManager.priceState {
                        await purchaseManager.purchaseSeasonPass()
                    } else {
                        await purchaseManager.loadProducts()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if purchaseManager.isPurchasing { ProgressView().tint(.white) }

                    let buttonTitle: String = {
                        if purchaseManager.isPurchasing {
                            return "Processing..."
                        } else if case .discovered = purchaseManager.priceState {
                            return "Buy Season Pass"
                        } else {
                            return "Retry Loading"
                        }
                    }()

                    Text(buttonTitle)
                        .bold()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? (extraCompact ? 8 : 10) : 14)
                .background(.blue, in: Capsule())
                .foregroundColor(.white)
            }
            .disabled(purchaseManager.isPurchasing || purchaseManager.priceState == .loading)

            Button {
                Task { await purchaseManager.restorePurchases() }
            } label: {
                Text("Check Purchase Status")
                    .font(compact ? (extraCompact ? .caption : .footnote) : .body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, compact ? (extraCompact ? 6 : 8) : 10)
                    .overlay(Capsule().stroke(.blue.opacity(0.4), lineWidth: 1))
            }
            .disabled(purchaseManager.isPurchasing)

            Text("The Season Pass is non-renewing. It unlocks ScoreKeep through \(productYear) and does not renew automatically.")
                .font(compact ? (extraCompact ? .caption2 : .caption) : .footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
    }

    @ViewBuilder
    private func benefitsGrid(compact: Bool, extraCompact: Bool) -> some View {
        let compactBenefits = [
            "Score every game",
            "Track team stats",
            "Coach-ready PDFs",
            "Unlimited rosters"
        ]
        let benefitsToShow = compact ? compactBenefits : benefits
        let spacing = compact ? (extraCompact ? 6 : 8) : 12
        let columns = Array(repeating: GridItem(.flexible(), spacing: CGFloat(spacing)), count: 2)

        LazyVGrid(columns: columns, alignment: .leading, spacing: CGFloat(spacing)) {
            ForEach(benefitsToShow, id: \.self) { item in
                HStack(spacing: CGFloat(spacing - 2)) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: compact ? (extraCompact ? 16 : 18) : 20))
                    Text(item)
                        .font(compact ? (extraCompact ? .footnote : .subheadline) : .body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(benefits, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(item)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func legalLinks(compact: Bool, extraCompact: Bool) -> some View {
        VStack(spacing: compact ? (extraCompact ? 4 : 6) : 8) {
            Divider().padding(.top, compact ? (extraCompact ? 2 : 4) : 8)

            HStack(spacing: compact ? (extraCompact ? 10 : 12) : 16) {
                Link(destination: privacyURL) {
                    Text("Privacy Policy")
                        .font(compact ? (extraCompact ? .caption : .footnote) : .footnote)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.08), in: Capsule())
                }
                Text("•")
                    .foregroundColor(.secondary)
                    .font(compact ? (extraCompact ? .caption : .footnote) : .footnote)
                Link(destination: eulaURL) {
                    Text("Terms / EULA")
                        .font(compact ? (extraCompact ? .caption : .footnote) : .footnote)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.08), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

