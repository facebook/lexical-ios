/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import UIKit

// TODO for see more:
// 1. correctly decode the 'bold' attribute using Lexical rules
// 2. Maybe cache the size of the attributed string?
// 3. test if the 'non-text' truncation (cut off half way through image/table) works [it doesn't seem to]
// 4. handle taps on See More, with a Lexical event
// 5. Component state for collapsed vs not
// 6. Have I got the textContainerInsets calculation wrong? Used plus instead of minus?

public class TextContainer: NSTextContainer {

  override public func lineFragmentRect(
    forProposedRect proposedRect: CGRect,
    at characterIndex: Int,
    writingDirection baseWritingDirection: NSWritingDirection,
    remaining remainingRect: UnsafeMutablePointer<CGRect>?
  ) -> CGRect {
    var lineFragmentRect = super.lineFragmentRect(forProposedRect: proposedRect,
                                                  at: characterIndex,
                                                  writingDirection: baseWritingDirection,
                                                  remaining: remainingRect)

    guard let layoutManager = layoutManager as? LayoutManager,
          case let .truncateLine(desiredTruncationLine) = layoutManager.activeTruncationMode,
          let truncationString = layoutManager.customTruncationString
    else {
      return lineFragmentRect
    }

    // check if we're looking at the last line
    guard lineFragmentRect.minY == desiredTruncationLine.minY else {
      return lineFragmentRect
    }

    // we have a match, and should truncate. Shrink the line by enough room to display our truncation string.
    let truncationAttributes = layoutManager.editor?.getTheme().truncationIndicatorAttributes ?? [:]
    let truncationAttributedString = NSAttributedString(string: truncationString, attributes: truncationAttributes)

    // assuming we don't make the line fragment rect bigger in order to fit the truncation string
    let requiredRect = truncationAttributedString.boundingRect(with: lineFragmentRect.size, options: .usesLineFragmentOrigin, context: nil)

    // TODO: derive this somehow
    let spacing = (requiredRect.width < 6) ? 0.0 : 6.0 // using this heuristic to detect 'blank line' and add no spacing

    // make the change
    lineFragmentRect.size.width = min(lineFragmentRect.width, size.width - (requiredRect.width + spacing))

    return lineFragmentRect
  }
}
