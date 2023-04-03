// swift-tools-version: 5.6
/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import PackageDescription

let package = Package(
  name: "Lexical",
  platforms: [.iOS(.v13)],
  products: [
    .library(
      name: "Lexical",
      targets: ["Lexical"]),
    .library(
      name: "LexicalListPlugin",
      targets: ["LexicalListPlugin"]),
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "Lexical",
      dependencies: [],
      path: "./Lexical"),
    .target(
      name: "LexicalListPlugin",
      dependencies: ["Lexical"],
      path: "./Plugins/LexicalListPlugin"),
    .testTarget(
      name: "LexicalTests",
      dependencies: ["Lexical"],
      path: "./LexicalTests")
  ]
)
