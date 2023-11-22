/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical
import LexicalLinkPlugin
import LexicalListPlugin
import SwiftMarkdown

private func makeIndentation(_ count: Int) -> String {
  String(repeating: "\u{009}", count: count)
}

public protocol NodeMarkdownBlockSupport: Lexical.Node {
  func exportBlockMarkdown() throws -> SwiftMarkdown.BlockMarkup
}

public protocol NodeMarkdownInlineSupport: Lexical.Node {
  func exportInlineMarkdown(indentation: Int) throws -> SwiftMarkdown.InlineMarkup
}

extension Lexical.ParagraphNode: NodeMarkdownBlockSupport {
  public func exportBlockMarkdown() throws -> SwiftMarkdown.BlockMarkup {
    return SwiftMarkdown.Paragraph(getChildren().exportAsInlineMarkdown(indentation: getIndent()))
  }
}

extension Lexical.TextNode: NodeMarkdownInlineSupport {
  public func exportInlineMarkdown(indentation: Int) throws -> SwiftMarkdown.InlineMarkup {
    let format = getFormat()
    var node: SwiftMarkdown.InlineMarkup = SwiftMarkdown.Text(makeIndentation(indentation) + getTextPart())

    if format.code {
      // NOTE (mani) - code must always come first
      node = SwiftMarkdown.InlineCode(makeIndentation(indentation) + getTextPart())
    }

    if format.bold {
      node = SwiftMarkdown.Strong(node)
    }

    if format.strikethrough {
      node = SwiftMarkdown.Strikethrough(node)
    }

    if format.italic {
      // TODO (mani) - underline + italic both use Emphasis node
      // should we create a separate node?
      node = SwiftMarkdown.Emphasis(node)
    }

    if format.underline {
      // TODO (mani) - underline + italic both use Emphasis node
      // should we create a separate node?
      node = SwiftMarkdown.Emphasis(node)
    }

    if format.superScript {
      // NOTE (mani) - unsupported
    }

    if format.subScript {
      // NOTE (mani) - unsupported
    }

    return node
  }
}

extension LexicalListPlugin.ListNode: NodeMarkdownBlockSupport {
  // NOTE (mani) - there are some oddities when converting lists
  // especially when lists have sub lists.
  // Sometimes Lexical will not realise that the top level list has been deleted
  // and so it will look like `List -> ListItem -> List -> [ListItem]` which outputs
  // incorrect markdown. Assume indentations are not properly supported.
  // Also, no support for checkmarks in Lexical AFAIK.

  public func exportBlockMarkdown() throws -> SwiftMarkdown.BlockMarkup {
    let children = getChildren().exportAsBlockMarkdown()
      .compactMap { $0 as? SwiftMarkdown.ListItem }
    switch getListType() {
    case .bullet:
      return SwiftMarkdown.UnorderedList(children)
    case .check:
      // TODO (mani) - how does lexical mark a checked item?
      return SwiftMarkdown.UnorderedList(children)
    case .number:
      var list = SwiftMarkdown.OrderedList(children)
      let start = getStart()
      if start > 0 {
        list.startIndex = UInt(start)
      }
      return list
    }
  }
}

extension LexicalListPlugin.ListItemNode: NodeMarkdownBlockSupport {
  public func exportBlockMarkdown() throws -> SwiftMarkdown.BlockMarkup {
    let children: [SwiftMarkdown.BlockMarkup] = getChildren().compactMap {
      if let inline = try? ($0 as? NodeMarkdownInlineSupport)?.exportInlineMarkdown(indentation: getIndent()) {
        return SwiftMarkdown.Paragraph(inline)
      } else {
        return try? ($0 as? NodeMarkdownBlockSupport)?.exportBlockMarkdown()
      }
    }

    if let parent = getParent() as? ListNode, parent.getListType() == .check {
      // TODO (mani) - how does lexical mark a checked item?
      return SwiftMarkdown.ListItem(checkbox: nil, children)
    } else {
      return SwiftMarkdown.ListItem(children)
    }
  }
}

extension LexicalLinkPlugin.LinkNode: NodeMarkdownInlineSupport {
  public func exportInlineMarkdown(indentation: Int) throws -> SwiftMarkdown.InlineMarkup {
    SwiftMarkdown.Link(destination: getURL(),
                       getChildren()
                        .exportAsInlineMarkdown(indentation: getIndent())
                        .compactMap { $0 as? SwiftMarkdown.RecurringInlineMarkup })
  }
}

extension Lexical.CodeNode: NodeMarkdownBlockSupport {
  public func exportBlockMarkdown() throws -> SwiftMarkdown.BlockMarkup {
    // TODO (mani) - do code blocks have formatting?
    // TODO (mani) - indentation for codeblocks?
    SwiftMarkdown.CodeBlock(getTextContent())
  }
}

extension Lexical.LineBreakNode: NodeMarkdownInlineSupport {
  public func exportInlineMarkdown(indentation: Int) throws -> SwiftMarkdown.InlineMarkup {
    SwiftMarkdown.LineBreak()
  }
}

extension Lexical.QuoteNode: NodeMarkdownBlockSupport {
  public func exportBlockMarkdown() throws -> SwiftMarkdown.BlockMarkup {
    SwiftMarkdown.BlockQuote(
      getChildren()
        .exportAsInlineMarkdown(indentation: getIndent())
        .map {
          SwiftMarkdown.Paragraph($0)
        }
    )
  }
}

extension Lexical.HeadingNode: NodeMarkdownBlockSupport {
  public func exportBlockMarkdown() throws -> SwiftMarkdown.BlockMarkup {
    SwiftMarkdown.Heading(
      level: getTag().intValue,
      getChildren().exportAsInlineMarkdown(indentation: getIndent())
    )
  }
}

private extension HeadingTagType {
  var intValue: Int {
    switch self {
    case .h1: return 1
    case .h2: return 2
    case .h3: return 3
    case .h4: return 4
    case .h5: return 5
    }
  }
}
