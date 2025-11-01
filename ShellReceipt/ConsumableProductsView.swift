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
    @State private var validationChoice: ValidationChoice = .apple
    private let networkHelper = NetworkHelper()

    private var consumableProducts: [SKProduct] {
        store.products.filter {
            consumableProductIDs.contains($0.productIdentifier)
        }
    }

    var body: some View {
        List {
            if ValidationChoice.allCases.count > 1 {
                Section("验单方式") {
                    Picker("验单方式", selection: $validationChoice) {
                        ForEach(ValidationChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

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
                where: consumableProductIDs.contains
            ) {
                Section("已购项目") {
                    ForEach(
                        store.purchasedProductIDs.filter(
                            consumableProductIDs.contains
                        ).sorted(),
                        id: \.self
                    ) { identifier in
                        Text(identifier)
                            .font(.footnote)
                    }
                }
            }

            Section {
                Button("验证凭证") {
                    Task {
                        await runValidation()
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
                    ProgressView(store.isRestoring ? "恢复中..." : "处理中...")
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

    private func runValidation() async {
        let productIDHint = store.purchasedProductIDs.filter(
            consumableProductIDs.contains
        ).sorted().last
        switch validationChoice {
        case .apple:
            do {
                _ = try await store.validateWithApple(
                    sharedSecret: appleSharedSecret,
                    productID: productIDHint
                )
            } catch {
                print(
                    "[Apple Validation] consumable error: \(error.localizedDescription)"
                )
            }
        case .server:
            do {
                let payload = try await store.fetchReceiptForServer(
                    productID: productIDHint
                )
                let resolvedID = payload.productID ?? productIDHint ?? "unknown"
                networkHelper.validateReceipt(
                    receipt: payload.base64Receipt,
                    productID: resolvedID
                )
            } catch {
                print(
                    "[Server Receipt] consumable error: \(error.localizedDescription)"
                )
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
        store.isPurchasing || store.isRestoring
    }
}
