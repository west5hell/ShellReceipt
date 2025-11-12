//
//  ContentView.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import StoreKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var storeKit1: StoreKitService
    @EnvironmentObject private var storeKit2: StoreKit2Service

    var body: some View {
        NavigationStack {
            List {
                Section("Examples") {
                    NavigationLink("Consumable Products") {
                        ConsumableProductsView()
                    }
                    NavigationLink("Subscription Products") {
                        SubscriptionProductsView()
                    }
                    NavigationLink("WebView Demo (Server Validation)") {
                        WebView()
                            .ignoresSafeArea()
                    }
                }

                Section("Subscription Status") {
                    HStack {
                        Text("Active Subscriber")
                        Spacer()
                        Text(storeKit2.subscriptionActive ? "Yes" : "No")
                            .foregroundColor(storeKit2.subscriptionActive ? .green : .primary)
                    }
                    ForEach(storeKit2.activeSubscriptionProductIDs.sorted(), id: \.self) {
                        Text($0)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button("Refresh Entitlements") {
                        Task {
                            await storeKit2.refreshEntitlements()
                        }
                    }
                    .disabled(storeKit2.isValidating)
                }
            }
            .navigationTitle("In-App Purchase Demo")
        }
        .task {
            if storeKit1.products.isEmpty {
                storeKit1.reloadProducts()
            }
            await storeKit2.loadProductsIfNeeded()
            await storeKit2.refreshEntitlements()
        }
    }
}
