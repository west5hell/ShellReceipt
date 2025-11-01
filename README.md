# ShellReceipt

示例项目演示了如何在 **SwiftUI + StoreKit 1** 环境中集成内购功能，并提供 WebView 场景下的远程验单示例。核心 `StoreKitService` 经过简化，可作为最小能力集合直接移植到其他项目中。

## 功能概览

- 加载内购商品（消耗型、订阅型）
- 购买、恢复购买
- 生成 App Store receipt，并可：
  - 直接向 Apple 服务器验证
  - 返回给自建服务器进行验单
- WebView 内执行购买请求并走服务器验单
- UI 层提供 SwiftUI 商品列表，并在购买/恢复期间显示全屏进度遮罩

## 快速接入 `StoreKitService`

1. **复制文件**

   - `ShellReceipt/StoreKitService.swift`
   - `ShellReceipt/WebView.swift`（如需 WebView 场景）
   - `ShellReceipt/demo.html`（可选，演示用）
   - `ShellReceipt/NetworkHelper`（示例网络工具，可替换为项目内实现）

2. **初始化服务**

   ```swift
   @main
   struct YourApp: App {
       @StateObject private var store = StoreKitService()

       var body: some Scene {
           WindowGroup {
               ContentView()
                   .environmentObject(store)
           }
       }
   }
   ```

3. **加载商品 & 购买**

   ```swift
   @EnvironmentObject private var store: StoreKitService

   // 加载商品
   .task { await store.reloadProducts() }

   // 购买
   store.purchase(product: product)

   // 恢复购买
   store.restorePurchases()
   ```

4. **验单**

   ```swift
   // Apple 验单（静默执行，可在控制台查看结果）
   do {
       let result = try await store.validateWithApple(
           sharedSecret: "your_shared_secret",
           productID: "optional_product_id"
       )
       print(result.environment, result.activeSubscriptions)
   } catch {
       print("Apple validation failed:", error)
   }

   // 自建服务器：获取最新 receipt，交由后端验证
   do {
       let payload = try await store.fetchReceiptForServer(productID: "optional_product_id")
       // 传给服务器
       networkHelper.validateReceipt(receipt: payload.base64Receipt,
                                     productID: payload.productID ?? "")
   } catch {
       print("Server receipt fetch failed:", error)
   }
   ```

5. **WebView 场景（可选）**
   - `WebView` 组件在 `demo.html` 中监听购买按钮，通过 `window.webkit.messageHandlers.purchase.postMessage` 将商品 ID 传回原生层。
   - `StoreKitService` 完成购买后调用 `fetchReceiptForServer`，示例中在控制台打印，实际项目可换成真实网络请求。

## 注意事项

- 商品/订阅 ID 目前写死在 `StoreKitService` 内；移植时根据实际情况调整或改为配置化。
- `NetworkHelper.validateReceipt` 仅作占位，请替换为真实的网络请求实现。
- 所有日志均打印到 Xcode 控制台；正式项目可加用户提示、错误上报等。
- 服务使用 `@MainActor` 管理状态，并确保所有 delegate 回调回到主线程，兼容 Swift 6 的严格隔离要求。

## 运行 Demo

1. 使用 Xcode 打开 `ShellReceipt.xcodeproj`
2. 运行到模拟器/真机
3. 进入 “消耗型商品”“订阅商品”“WebView 购买示例” 体验不同场景
4. 查看 Xcode 控制台了解购买、验单日志输出
