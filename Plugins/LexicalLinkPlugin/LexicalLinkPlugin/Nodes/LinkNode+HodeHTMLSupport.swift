/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Lexical
import LexicalHTML
import SwiftSoup

extension LinkNode: NodeHTMLSupport {
  public static func importDOM(domNode: SwiftSoup.Node) throws -> LexicalHTML.DOMConversionOutput {
    return (after: nil, forChild: nil, node: [])
  }
  
  public func exportDOM(editor: Lexical.Editor) throws -> LexicalHTML.DOMExportOutput {
    let attributes = Attributes()
    try attributes.put(attribute: Attribute(key: "href", value: url))
    let dom = SwiftSoup.Element(Tag("a"), "", attributes)
    return (after: nil, element: dom)
  }
}
