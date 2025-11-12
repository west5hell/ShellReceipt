//
//  SubscriptionProductsView.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import StoreKit
import SwiftUI

struct SubscriptionProductsView: View {
    @EnvironmentObject private var store: StoreKit2Service
    @State private var purchaseAlert: PurchaseAlert?

    private var subscriptionProducts: [Product] {
        store.products.filter { ProductCatalog.subscriptionProducts.contains($0.id) }
    }

    var body: some View {
        List {
            subscriptionStatusSection
            productsSection
            currentSubscriptionSection
            actionSection
        }
        .navigationTitle("Subscriptions (StoreKit 2)")
        .toolbar { reloadToolbar }
        .task { await loadInitialData() }
        .overlay { busyOverlay }
        .alert(item: $purchaseAlert) { alert in
            Alert(
                title: Text("Purchase Result"),
                message: Text(alert.message),
                dismissButton: .cancel(Text("OK")) { purchaseAlert = nil }
            )
        }
    }

    private var subscriptionStatusSection: some View {
        Section("Subscription Status") {
            HStack {
                Text("Active Subscriber")
                Spacer()
                Text(store.subscriptionActive ? "Yes" : "No")
                    .foregroundColor(store.subscriptionActive ? .green : .primary)
            }
            ForEach(store.activeSubscriptionProductIDs.sorted(), id: \.self) { productID in
                Text(productID)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var productsSection: some View {
        Section("Products") {
            if subscriptionProducts.isEmpty {
                Text("No products loaded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(subscriptionProducts, id: \.id) { product in
                    productRow(product)
                }
            }
        }
    }

    private func productRow(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(product.displayName)
                .font(.headline)
            Text(product.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(product.displayPrice)
                    .font(.subheadline)
                Spacer()
                Button("Buy") {
                    Task {
                        if let message = await store.purchase(product: product) {
                            await MainActor.run {
                                purchaseAlert = PurchaseAlert(message: message)
                            }
                        }
                    }
                }
                .disabled(isBusy)
            }
        }
        .padding(.vertical, 6)
    }

    private var currentSubscriptionSection: some View {
        Group {
            if let active = store.activeSubscriptionProductIDs.sorted().first {
                Section("Current Subscription") {
                    Text(active)
                        .font(.footnote)
                }
            }
        }
    }

    private var actionSection: some View {
        Section {
            Button("Refresh Entitlements") {
                Task { await store.refreshEntitlements() }
            }
            .disabled(store.isValidating)
            Button("Restore Purchases") {
                store.restorePurchases()
            }
            .disabled(isBusy)
        }
    }

    private var reloadToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Reload Products") {
                Task { await store.loadProducts() }
            }
        }
    }

    private func loadInitialData() async {
        await store.loadProductsIfNeeded()
        await store.refreshEntitlements()
    }

    private var busyOverlay: some View {
        Group {
            if isBusy {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView(busyStatusText)
                        .padding(20)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                        )
                }
            }
        }
    }

    private var isBusy: Bool {
        store.isPurchasing || store.isRestoring || store.isValidating || store.isLoadingProducts
    }

    private var busyStatusText: String {
        if store.isRestoring { return "Restoring..." }
        if store.isValidating { return "Refreshing..." }
        if store.isLoadingProducts { return "Loading..." }
        return "Processing..."
    }
}
