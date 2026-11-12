// swift-tools-version: 6.0
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
// 讓其他專案能以 git 相依引用編輯核心（SwiftPM 只認儲存庫根目錄的 Package.swift）：
// 這裡只是把 Packages/OKMMead 的同一份原始碼再公開一次，不含 App 殼層。
// OKM Mead App 本身仍經 project.yml 引用 Packages/OKMMead；兩份 Package.swift 的相依、資源與平台設定必須保持一致。
import PackageDescription

let package = Package(
    name: "okm-mead",
    defaultLocalization: "zh-Hant",
    platforms: [.macOS(.v15)],
    products: [.library(name: "OKMMead", targets: ["OKMMead"])],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown", exact: "0.9.0"),
    ],
    targets: [
        .target(
            name: "OKMMead",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")],
            path: "Packages/OKMMead/Sources/OKMMead",
            resources: [.copy("Resources/diagram.js"), .copy("Resources/export.css"), .process("Resources/Localizable.xcstrings")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
