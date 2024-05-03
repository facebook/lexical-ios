/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical
import Markdown

extension Array where Element == Node {
  public func exportAsInlineMarkdown() -> [Markdown.InlineMarkup] {
    compactMap {
      try? ($0 as? NodeMarkdownInlineSupport)?.exportInlineMarkdown()
    }
  }

  public func exportAsBlockMarkdown() -> [Markdown.BlockMarkup] {
    compactMap {
      try? ($0 as? NodeMarkdownBlockSupport)?.exportBlockMarkdown()
    }
  }
}
