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
    @State private var purchaseMessage: String?

    private var subscriptionProducts: [Product] {
        store.products.filter {
            ProductCatalog.subscriptionProducts.contains($0.id)
        }
    }

    var body: some View {
        List {
            Section("Subscription Status") {
                HStack {
                    Text("Active Subscriber")
                    Spacer()
                    Text(store.subscriptionActive ? "Yes" : "No")
                        .foregroundColor(store.subscriptionActive ? .green : .primary)
                }
                ForEach(store.activeSubscriptionProductIDs.sorted(), id: \.self) {
                    Text($0)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Products") {
                if subscriptionProducts.isEmpty {
                    Text("No products loaded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(subscriptionProducts, id: \.id) { product in
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
                                        let message = await store.purchase(product: product)
                                        purchaseMessage = message
                                    }
                                }
                                .disabled(isBusy)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            if let active = store.activeSubscriptionProductIDs.sorted().first {
                Section("Current Subscription") {
                    Text(active)
                        .font(.footnote)
                }
            }

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
        .navigationTitle("Subscriptions (StoreKit 2)")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reload Products") {
                    Task { await store.loadProducts() }
                }
            }
        }
        .task {
            await store.loadProductsIfNeeded()
            await store.refreshEntitlements()
        }
        .overlay {
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
        .alert("Purchase Result", isPresented: Binding<Bool>(
            get: { purchaseMessage != nil },
            set: { if !$0 { purchaseMessage = nil } }
        )) {
            Button("OK", role: .cancel) { purchaseMessage = nil }
        } message: {
            Text(purchaseMessage ?? "")
        }
    }

    private var isBusy: Bool {
        store.isPurchasing || store.isRestoring || store.isValidating
            || store.isLoadingProducts
    }

    private var busyStatusText: String {
        if store.isRestoring {
            return "Restoring..."
        }
        if store.isValidating {
            return "Refreshing..."
        }
        if store.isLoadingProducts {
            return "Loading..."
        }
        return "Processing..."
    }
}
