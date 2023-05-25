/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Lexical
import SwiftSoup

public typealias DOMConversionOutputAfter = ([Lexical.Node]) throws -> [Lexical.Node]
public typealias DOMChildConversion = (Lexical.Node, Lexical.Node?) throws -> Lexical.Node? // arguments: node, parent
public typealias DOMConversionOutput = (after: DOMConversionOutputAfter?, forChild: DOMChildConversion?, node: [Lexical.Node])

public typealias DOMExportOutputAfter = (Lexical.Node, SwiftSoup.Element?) throws -> SwiftSoup.Element?
public typealias DOMExportOutput = (after: DOMExportOutputAfter?, element: SwiftSoup.Element?)

public protocol NodeHTMLSupport: Lexical.Node {
  static func importDOM(domNode: SwiftSoup.Node) throws -> DOMConversionOutput
  func exportDOM(editor: Editor) throws -> DOMExportOutput
}
