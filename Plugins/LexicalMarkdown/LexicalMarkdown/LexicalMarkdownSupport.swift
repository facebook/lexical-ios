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
import Markdown

private func makeIndentation(_ count: Int) -> String {
  String(repeating: "\u{009}", count: count)
}

public protocol NodeMarkdownBlockSupport: Lexical.Node {
  func exportBlockMarkdown() throws -> Markdown.BlockMarkup
}

public protocol NodeMarkdownInlineSupport: Lexical.Node {
  func exportInlineMarkdown() throws -> Markdown.InlineMarkup
}

extension Lexical.ParagraphNode: NodeMarkdownBlockSupport {
  public func exportBlockMarkdown() throws -> Markdown.BlockMarkup {
    return Markdown.Paragraph(getChildren().exportAsInlineMarkdown())
  }
}

extension Lexical.TextNode: NodeMarkdownInlineSupport {
  public func exportInlineMarkdown() throws -> Markdown.InlineMarkup {
    let format = getFormat()
    var node: Markdown.InlineMarkup = Markdown.Text(getTextPart())

    if format.code {
      // NOTE (mani) - code must always come first
      node = Markdown.InlineCode(getTextPart())
    }

    if format.bold {
      node = Markdown.Strong(node)
    }

    if format.strikethrough {
      node = Markdown.Strikethrough(node)
    }

    if format.italic {
      // TODO (mani) - underline + italic both use Emphasis node
      // should we create a separate node?
      node = Markdown.Emphasis(node)
    }

    if format.underline {
      // TODO (mani) - underline + italic both use Emphasis node
      // should we create a separate node?
      node = Markdown.Emphasis(node)
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

  public func exportBlockMarkdown() throws -> Markdown.BlockMarkup {
    let children = getChildren().exportAsBlockMarkdown()
      .compactMap { $0 as? Markdown.ListItem }
    switch getListType() {
    case .bullet:
      return Markdown.UnorderedList(children)
    case .check:
      // TODO (mani) - how does lexical mark a checked item?
      return Markdown.UnorderedList(children)
    case .number:
      var list = Markdown.OrderedList(children)
      let start = getStart()
      if start > 0 {
        list.startIndex = UInt(start)
      }
      return list
    }
  }
}

extension LexicalListPlugin.ListItemNode: NodeMarkdownBlockSupport {
  public func exportBlockMarkdown() throws -> Markdown.BlockMarkup {
    var blocks: [BlockMarkup] = []
    var inlineAccumulator: [InlineMarkup] = []
    for child in getChildren() {
      if let child = child as? NodeMarkdownBlockSupport {
        if inlineAccumulator.count > 0 {
          blocks.append(Paragraph(inlineAccumulator))
          inlineAccumulator = []
        }
        blocks.append(try child.exportBlockMarkdown())
        continue
      }
      if let child = child as? NodeMarkdownInlineSupport {
        inlineAccumulator.append(try child.exportInlineMarkdown())
        continue
      }
    }
    if inlineAccumulator.count > 0 {
      blocks.append(Paragraph(inlineAccumulator))
    }

    if let parent = getParent() as? ListNode, parent.getListType() == .check {
      // TODO (mani) - how does lexical mark a checked item?
      return Markdown.ListItem(checkbox: nil, blocks)
    } else {
      return Markdown.ListItem(blocks)
    }
  }
}

extension LexicalLinkPlugin.LinkNode: NodeMarkdownInlineSupport {
  public func exportInlineMarkdown() throws -> Markdown.InlineMarkup {
    Markdown.Link(
      destination: getURL(),
      getChildren()
        .exportAsInlineMarkdown()
        .compactMap { $0 as? Markdown.RecurringInlineMarkup })
  }
}

extension Lexical.CodeNode: NodeMarkdownBlockSupport {
  public func exportBlockMarkdown() throws -> Markdown.BlockMarkup {
    // TODO (mani) - do code blocks have formatting?
    // TODO (mani) - indentation for codeblocks?
    Markdown.CodeBlock(getTextContent())
  }
}

extension Lexical.LineBreakNode: NodeMarkdownInlineSupport {
  public func exportInlineMarkdown() throws -> Markdown.InlineMarkup {
    Markdown.LineBreak()
  }
}

extension Lexical.QuoteNode: NodeMarkdownBlockSupport {
  public func exportBlockMarkdown() throws -> Markdown.BlockMarkup {
    Markdown.BlockQuote(
      getChildren()
        .exportAsInlineMarkdown()
        .map {
          Markdown.Paragraph($0)
        }
    )
  }
}

extension Lexical.HeadingNode: NodeMarkdownBlockSupport {
  public func exportBlockMarkdown() throws -> Markdown.BlockMarkup {
    Markdown.Heading(
      level: getTag().intValue,
      getChildren().exportAsInlineMarkdown()
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
