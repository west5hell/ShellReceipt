//
//  SubscriptionProductsView.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import StoreKit
import SwiftUI

struct SubscriptionProductsView: View {
    @EnvironmentObject private var store: StoreKitService
    private var subscriptionProducts: [SKProduct] {
        store.products.filter {
            ProductCatalog.subscriptionProducts.contains($0.productIdentifier)
        }
    }

    var body: some View {
        List {
            Section("订阅状态") {
                HStack {
                    Text("订阅用户")
                    Spacer()
                    Text(store.subscriptionActive ? "是" : "否")
                        .foregroundColor(
                            store.subscriptionActive ? .green : .primary
                        )
                }
                ForEach(store.activeSubscriptionProductIDs.sorted(), id: \.self)
                { identifier in
                    Text(identifier)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("商品") {
                if subscriptionProducts.isEmpty {
                    Text("尚未加载到商品。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(subscriptionProducts, id: \.identifiableID) {
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

            if let first = store.activeSubscriptionProductIDs.first {
                Section("当前订阅") {
                    Text(first)
                        .font(.footnote)
                }
            }

            Section {
                Button("恢复购买") {
                    store.restorePurchases()
                }
                .disabled(isBusy)
            }
        }
        .navigationTitle("订阅商品")
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
