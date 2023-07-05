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
    .library(
      name: "LexicalListHTMLSupport",
      targets: ["LexicalListHTMLSupport"]),
    .library(
      name: "LexicalHTML",
      targets: ["LexicalHTML"]),
    .library(
      name: "LexicalLinkPlugin",
      targets: ["LexicalLinkPlugin"]),
    .library(
      name: "LexicalInlineImagePlugin",
      targets: ["LexicalInlineImagePlugin"]),
  ],
  dependencies: [
    .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
  ],
  targets: [
    .target(
      name: "Lexical",
      dependencies: [],
      path: "./Lexical"),
    .testTarget(
      name: "LexicalTests",
      dependencies: ["Lexical"],
      path: "./LexicalTests"),

    .target(
      name: "LexicalListPlugin",
      dependencies: ["Lexical"],
      path: "./Plugins/LexicalListPlugin/LexicalListPlugin"),
    .target(
      name: "LexicalListHTMLSupport",
      dependencies: ["Lexical", "LexicalListPlugin", "LexicalHTML"],
      path: "./Plugins/LexicalListPlugin/LexicalListHTMLSupport"),

    .target(
      name: "LexicalHTML",
      dependencies: ["Lexical", "SwiftSoup"],
      path: "./Plugins/LexicalHTML/LexicalHTML"),
    .testTarget(
      name: "LexicalHTMLTests",
      dependencies: ["Lexical", "LexicalHTML", "SwiftSoup"],
      path: "./Plugins/LexicalHTML/LexicalHTMLTests"),

    .target(
      name: "LexicalLinkPlugin",
      dependencies: ["Lexical"],
      path: "./Plugins/LexicalLinkPlugin/LexicalLinkPlugin"),
    .testTarget(
      name: "LexicalLinkPluginTests",
      dependencies: ["Lexical", "LexicalLinkPlugin"],
      path: "./Plugins/LexicalLinkPlugin/LexicalLinkPluginTests"),

    .target(
      name: "LexicalInlineImagePlugin",
      dependencies: ["Lexical"],
      path: "./Plugins/LexicalInlineImagePlugin/LexicalInlineImagePlugin"),
    .testTarget(
      name: "LexicalInlineImagePluginTests",
      dependencies: ["Lexical", "LexicalInlineImagePlugin"],
      path: "./Plugins/LexicalInlineImagePlugin/LexicalInlineImagePluginTests"),
  ]
)
