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
    let outerTag = getFormat().code ? "code" : "span"

    var element = SwiftSoup.Element(Tag(outerTag), "")
    try element.appendText(self.getTextPart())

    if getFormat().bold {
      element = try wrapDomElement(element, with: "b")
    }
    if getFormat().italic {
      element = try wrapDomElement(element, with: "i")
    }
    if getFormat().strikethrough {
      element = try wrapDomElement(element, with: "s")
    }
    if getFormat().underline {
      element = try wrapDomElement(element, with: "u")
    }

    return (after: nil, element: element)
  }

  private func wrapDomElement(_ element: SwiftSoup.Element, with tagString: String) throws -> SwiftSoup.Element {
    let newElement = SwiftSoup.Element(Tag(tagString), "")
    try newElement.appendChild(element)
    return newElement
  }
}

extension Lexical.CodeNode: NodeHTMLSupport {
  public static func importDOM(domNode: SwiftSoup.Node) throws -> DOMConversionOutput {
    return (after: nil, forChild: nil, node: [])
  }

  public func exportDOM(editor: Lexical.Editor) throws -> DOMExportOutput {
    let dom = SwiftSoup.Element(Tag("code"), "")
    return (after: nil, element: dom)
  }
}

extension Lexical.LineBreakNode: NodeHTMLSupport {
  public static func importDOM(domNode: SwiftSoup.Node) throws -> DOMConversionOutput {
    return (after: nil, forChild: nil, node: [])
  }

  public func exportDOM(editor: Lexical.Editor) throws -> DOMExportOutput {
    let dom = SwiftSoup.Element(Tag("br"), "")
    return (after: nil, element: dom)
  }
}

extension Lexical.QuoteNode: NodeHTMLSupport {
  public static func importDOM(domNode: SwiftSoup.Node) throws -> DOMConversionOutput {
    return (after: nil, forChild: nil, node: [])
  }

  public func exportDOM(editor: Lexical.Editor) throws -> DOMExportOutput {
    let dom = SwiftSoup.Element(Tag("blockquote"), "")
    return (after: nil, element: dom)
  }
}

extension Lexical.HeadingNode: NodeHTMLSupport {
  public static func importDOM(domNode: SwiftSoup.Node) throws -> DOMConversionOutput {
    return (after: nil, forChild: nil, node: [])
  }

  public func exportDOM(editor: Lexical.Editor) throws -> DOMExportOutput {
    let tag = self.getTag().rawValue
    let dom = SwiftSoup.Element(Tag(tag), "")
    return (after: nil, element: dom)
  }
}
