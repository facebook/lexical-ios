/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical
import SwiftMarkdown

extension Array where Element == Node {
  func exportAsInlineMarkdown(indentation: Int) -> [SwiftMarkdown.InlineMarkup] {
    compactMap {
      try? ($0 as? NodeMarkdownInlineSupport)?.exportInlineMarkdown(indentation: indentation)
    }
  }

  func exportAsBlockMarkdown() -> [SwiftMarkdown.BlockMarkup] {
    compactMap {
      try? ($0 as? NodeMarkdownBlockSupport)?.exportBlockMarkdown()
    }
  }
}
