//
//  ConsumableProductsView.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import StoreKit
import SwiftUI

struct ConsumableProductsView: View {
    @EnvironmentObject private var store: StoreKit2Service
    @State private var purchaseMessage: String?

    private var consumableProducts: [Product] {
        store.products.filter {
            ProductCatalog.consumableProducts.contains($0.id)
        }
    }

    var body: some View {
        List {
            Section("Products") {
                if consumableProducts.isEmpty {
                    Text("No products loaded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(consumableProducts, id: \.id) { product in
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

            if store.purchasedProductIDs.contains(
                where: ProductCatalog.consumableProducts.contains
            ) {
                Section("Previous Purchases") {
                    ForEach(
                        store.purchasedProductIDs.filter(
                            ProductCatalog.consumableProducts.contains
                        ).sorted(),
                        id: \.self
                    ) { identifier in
                        Text(identifier)
                            .font(.footnote)
                    }
                }
            }
        }
        .navigationTitle("Consumables (StoreKit 2)")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reload Products") {
                    Task { await store.loadProducts() }
                }
            }
        }
        .task { await store.loadProductsIfNeeded() }
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
