//
//  PaywallView.swift
//  ScoreKeep
//
//  Created by Karl Keller on 11/24/25.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var title: String = "ScoreKeep Season Pass"
    var benefits: [String] = [
        "Unlimited scoring and stats",
        "Share and import teams/games",
        "PDF exports and reports",
        "Priority updates"
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
                            // Header (no inline nav title to save space)
                            header(compact: true, extraCompact: extraCompact, showInlineTitle: false)

                            // Price + CTA
                            priceAndCTA(compact: true, extraCompact: extraCompact)

                            // Benefits grid
                            benefitsGrid(compact: true, extraCompact: extraCompact)

                            // Legal links
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
            // Hide nav title on iPhone to reclaim vertical space
            .navigationTitle(UIDevice.type == "iPhone" ? "Upgrade" : "Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(purchaseManager.$isSeasonPassActive) { active in
                if active { dismiss() }
            }
            .onChange(of: purchaseManager.lastErrorMessage) {
                showingError = (purchaseManager.lastErrorMessage?.isEmpty == false)
            }
            .alert(purchaseManager.lastErrorMessage ?? "", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            }
        }
        .task {
            if scenePhase == .active, purchaseManager.seasonPassProduct == nil {
                await purchaseManager.loadProducts()
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, purchaseManager.seasonPassProduct == nil {
                Task { await purchaseManager.loadProducts() }
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

            Text(title)
                .font(compact ? (extraCompact ? .headline.bold() : .title3.bold()) : .title2.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text("Unlimited Downloads and Scoring Games for 1 year")
                .font(compact ? (extraCompact ? .footnote : .subheadline) : .body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(compact ? 1 : 2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func priceAndCTA(compact: Bool, extraCompact: Bool) -> some View {
        VStack(spacing: compact ? (extraCompact ? 8 : 10) : 12) {
            if let product = purchaseManager.seasonPassProduct {
                Text(product.displayPrice)
                    .font(compact ? (extraCompact ? .title3.bold() : .title2.bold()) : .largeTitle.bold())
                    .accessibilityLabel("Price \(product.displayPrice)")
            } else {
                ProgressView().progressViewStyle(.circular)
            }

            Button {
                Task {
                    if let product = purchaseManager.seasonPassProduct {
                        await purchaseManager.purchase(product: product)
                    } else {
                        await purchaseManager.loadProducts()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if purchaseManager.isPurchasing { ProgressView().tint(.white) }
                    Text(purchaseManager.isPurchasing ? "Processing..." : "Continue")
                        .bold()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? (extraCompact ? 8 : 10) : 14)
                .background(.blue, in: Capsule())
                .foregroundColor(.white)
            }
            .disabled(purchaseManager.isPurchasing)

            Button {
                Task { await purchaseManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(compact ? (extraCompact ? .caption : .footnote) : .body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, compact ? (extraCompact ? 6 : 8) : 10)
                    .overlay(Capsule().stroke(.blue.opacity(0.4), lineWidth: 1))
            }
            .disabled(purchaseManager.isPurchasing)
        }
    }

    @ViewBuilder
    private func benefitsGrid(compact: Bool, extraCompact: Bool) -> some View {
        let compactBenefits = [
            "Unlimited scoring & stats",
            "Share teams & games",
            "PDF exports",
            "Priority updates"
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
