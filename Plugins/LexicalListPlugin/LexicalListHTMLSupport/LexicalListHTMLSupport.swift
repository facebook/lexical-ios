/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical
import LexicalHTML
import LexicalListPlugin
import SwiftSoup

extension LexicalListPlugin.ListNode: NodeHTMLSupport {
  public static func importDOM(domNode: SwiftSoup.Node) throws -> DOMConversionOutput {
    return (after: nil, forChild: nil, node: [])
  }

  public func exportDOM(editor: Lexical.Editor) throws -> DOMExportOutput {
    let tag = self.getListType() == .number ? "ol" : "ul"
    let dom = SwiftSoup.Element(Tag(tag), "")

    if getStart() != 1 {
      try dom.attr("start", "\(getStart())")
    }

    return (after: nil, element: dom)
  }
}

extension LexicalListPlugin.ListItemNode: NodeHTMLSupport {
  public static func importDOM(domNode: SwiftSoup.Node) throws -> DOMConversionOutput {
    return (after: nil, forChild: nil, node: [])
  }

  public func exportDOM(editor: Lexical.Editor) throws -> DOMExportOutput {
    let dom = SwiftSoup.Element(Tag("li"), "")
    if getValue() > 0 {
      try dom.attr("value", "\(getValue())")
    }
    return (after: nil, element: dom)
  }
}
