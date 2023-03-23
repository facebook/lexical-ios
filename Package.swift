// swift-tools-version: 5.6

// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import PackageDescription

let package = Package(
  name: "Lexical",
  platforms: [.iOS(.v13)],
  products: [
    .library(
      name: "Lexical",
      targets: ["Lexical"]),
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "Lexical",
      dependencies: [],
      path: "./Lexical"),
    .testTarget(
      name: "LexicalTests",
      dependencies: ["Lexical"],
      path: "./LexicalTests")
  ]
)
