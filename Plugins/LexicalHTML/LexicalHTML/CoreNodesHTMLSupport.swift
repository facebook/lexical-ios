/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Lexical
import SwiftSoup

extension Lexical.ParagraphNode: NodeHTMLSupport {
  public static func importDOM(domNode: SwiftSoup.Node) throws -> DOMConversionOutput {
    return (after: nil, forChild: nil, node: [])
  }

  public func exportDOM(editor: Lexical.Editor) throws -> DOMExportOutput {
    let dom = SwiftSoup.Element(Tag("p"), "")
    return (after: nil, element: dom)
  }
}

extension Lexical.TextNode: NodeHTMLSupport {
  public static func importDOM(domNode: SwiftSoup.Node) throws -> DOMConversionOutput {
    return (after: nil, forChild: nil, node: [])
  }

  public func exportDOM(editor: Lexical.Editor) throws -> DOMExportOutput {
    let dom = SwiftSoup.Element(Tag("span"), "")
    try dom.appendText(self.getTextPart())
    return (after: nil, element: dom)
  }
}
