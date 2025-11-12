//
//  ContentView.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import StoreKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: StoreKitService
    private let networkHelper = NetworkHelper()

    var body: some View {
        NavigationStack {
            List {
                Section("功能演示") {
                    NavigationLink("消耗型商品") {
                        ConsumableProductsView()
                    }
                    NavigationLink("订阅商品") {
                        SubscriptionProductsView()
                    }
                    NavigationLink("WebView 购买示例") {
                        WebView()
                            .ignoresSafeArea()
                    }
                }

                Section("当前状态") {
                    HStack {
                        Text("订阅用户")
                        Spacer()
                        Text(store.subscriptionActive ? "是" : "否")
                            .foregroundColor(
                                store.subscriptionActive ? .green : .primary
                            )
                    }
                    ForEach(
                        store.activeSubscriptionProductIDs.sorted(),
                        id: \.self
                    ) { identifier in
                        Text(identifier)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button("验证凭证") {
                        Task {
                            do {
                                _ = try await store.validateWithServer(
                                    networkHelper: networkHelper,
                                    productID: nil
                                )
                            } catch {
                                print(
                                    "[Server Validation] manual refresh failed: \(error.localizedDescription)"
                                )
                            }
                        }
                    }
                    .disabled(store.isValidating)
                }
            }
            .navigationTitle("内购示例")
        }
        .task {
            if store.products.isEmpty {
                store.reloadProducts()
            }
        }
    }
}
