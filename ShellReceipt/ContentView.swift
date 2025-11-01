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
                    Button("刷新订阅状态") {
                        Task {
                            do {
                                _ = try await store.validateWithApple(
                                    sharedSecret: appleSharedSecret,
                                    productID: nil
                                )
                            } catch {
                                print(
                                    "[Apple Validation] manual refresh failed: \(error.localizedDescription)"
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("内购示例")
        }
        .task {
            if store.products.isEmpty {
                store.reloadProducts()
            }
            do {
                _ = try await store.validateWithApple(
                    sharedSecret: appleSharedSecret,
                    productID: nil
                )
            } catch {
                print(
                    "[Apple Validation] initial check failed: \(error.localizedDescription)"
                )
            }
        }
    }
}
