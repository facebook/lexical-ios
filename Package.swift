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
    .library(
      name: "SelectableDecoratorNode",
      targets: ["SelectableDecoratorNode"]),
    .library(
      name: "EditorHistoryPlugin",
      targets: ["EditorHistoryPlugin"]),
    .library(
      name: "LexicalMarkdown",
      targets: ["LexicalMarkdown"]),
  ],
  dependencies: [
    .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
    .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
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
    .testTarget(
      name: "LexicalListPluginTests",
      dependencies: ["Lexical", "LexicalListPlugin"],
      path: "./Plugins/LexicalListPlugin/LexicalListPluginTests"),
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
      dependencies: ["Lexical", "SelectableDecoratorNode", "LexicalHTML"],
      path: "./Plugins/LexicalInlineImagePlugin/LexicalInlineImagePlugin"),
    .testTarget(
      name: "LexicalInlineImagePluginTests",
      dependencies: ["Lexical", "LexicalInlineImagePlugin"],
      path: "./Plugins/LexicalInlineImagePlugin/LexicalInlineImagePluginTests"),

    .target(
      name: "SelectableDecoratorNode",
      dependencies: ["Lexical"],
      path: "./Plugins/SelectableDecoratorNode/SelectableDecoratorNode"),

    .target(
      name: "EditorHistoryPlugin",
      dependencies: ["Lexical"],
      path: "./Plugins/EditorHistoryPlugin/EditorHistoryPlugin"),
    .testTarget(
      name: "EditorHistoryPluginTests",
      dependencies: ["Lexical", "EditorHistoryPlugin"],
      path: "./Plugins/EditorHistoryPlugin/EditorHistoryPluginTests"),

    .target(
      name: "LexicalMarkdown",
      dependencies: [
        "Lexical",
        "LexicalLinkPlugin",
        "LexicalListPlugin",
        .product(name: "Markdown", package: "swift-markdown")
      ],
      path: "./Plugins/LexicalMarkdown/LexicalMarkdown"),
    .testTarget(
      name: "LexicalMarkdownTests",
      dependencies: [
        "Lexical",
        "LexicalMarkdown",
        .product(name: "Markdown", package: "swift-markdown"),
      ],
      path: "./Plugins/LexicalMarkdown/LexicalMarkdownTests"),
  ]
)
