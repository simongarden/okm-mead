// swift-tools-version: 6.0
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
// OKM Mead 的編輯核心（Swift 6＋TextKit 2 的所見即所得 Markdown 編輯器，MIT，見 LICENSE），由 OKM Mead 與 OKM Mimir 共用；
// 以 simongarden/okm-mead 的 Packages/OKMMead 為準。不含 App 殼層、更新機制與商標圖形。
// 配色由使用端經 MeadConfiguration 注入；介面文字放在 Resources/Localizable.xcstrings（以中文原文為 key）。
import PackageDescription

let package = Package(
    name: "OKMMead",
    defaultLocalization: "zh-Hant",
    platforms: [.macOS(.v15)],
    products: [.library(name: "OKMMead", targets: ["OKMMead"])],
    dependencies: [
        // Markdown 解析（Apache-2.0，連帶使用 swift-cmark）；精確釘選，原始碼見 ThirdPartySources。
        .package(url: "https://github.com/swiftlang/swift-markdown", exact: "0.9.0"),
    ],
    targets: [
        .target(
            name: "OKMMead",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")],
            resources: [.copy("Resources/diagram.js"), .copy("Resources/export.css"), .process("Resources/Localizable.xcstrings")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
