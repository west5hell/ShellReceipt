//
//  ConsumableProductsView.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import StoreKit
import SwiftUI

struct ConsumableProductsView: View {
    @EnvironmentObject private var store: StoreKitService
    private var consumableProducts: [SKProduct] {
        store.products.filter {
            ProductCatalog.consumableProducts.contains($0.productIdentifier)
        }
    }

    var body: some View {
        List {
            Section("商品") {
                if consumableProducts.isEmpty {
                    Text("尚未加载到商品。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(consumableProducts, id: \.identifiableID) {
                        product in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(product.localizedTitle)
                                .font(.headline)
                            Text(product.localizedDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(priceString(for: product))
                                    .font(.subheadline)
                                Spacer()
                                Button("购买") {
                                    store.purchase(product: product)
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
                Section("已购项目") {
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
        .navigationTitle("消耗型商品")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("刷新商品") {
                    store.reloadProducts()
                }
            }
        }
        .task {
            if store.products.isEmpty {
                store.reloadProducts()
            }
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
    }

    private func priceString(for product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price)
            ?? product.price.stringValue
    }

    private var isBusy: Bool {
        store.isPurchasing || store.isRestoring || store.isValidating
    }

    private var busyStatusText: String {
        if store.isRestoring {
            return "恢复中..."
        }
        if store.isValidating {
            return "验单中..."
        }
        return "处理中..."
    }
}
