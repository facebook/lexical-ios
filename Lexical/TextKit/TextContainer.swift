/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
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

  internal var readOnlySizeCache: LexicalReadOnlySizeCache?

  override open var isSimpleRectangularTextContainer: Bool {
    get {
      guard let readOnlySizeCache else { return true }

      // if we're limiting height, AND there's a custom truncation string, then we're maybe not rectangular. Otherwise we definitely are.
      if readOnlySizeCache.requiredHeight != nil {
        return (readOnlySizeCache.customTruncationString == nil)
      }
      return true
    }
  }

  override public func lineFragmentRect(
    forProposedRect proposedRect: CGRect,
    at characterIndex: Int,
    writingDirection baseWritingDirection: NSWritingDirection,
    remaining remainingRect: UnsafeMutablePointer<CGRect>?
  ) -> CGRect {
    var lineFragmentRect = super.lineFragmentRect(
      forProposedRect: proposedRect,
      at: characterIndex,
      writingDirection: baseWritingDirection,
      remaining: remainingRect)

    guard let readOnlySizeCache,
          let characterRange = readOnlySizeCache.characterRangeForLastLineFragmentBeforeTruncation,
          let glyphRange = readOnlySizeCache.glyphRangeForLastLineFragmentBeforeTruncation,
          let cutPoint = readOnlySizeCache.glyphIndexAtTruncationIndicatorCutPoint,
          NSLocationInRange(characterIndex, characterRange),
          let sizeForTruncationString = readOnlySizeCache.sizeForTruncationString
    else {
      return lineFragmentRect
    }

    // can we shrink the line? Or should we display truncation indicator below?
    let glyphsBeforeIndicator = cutPoint - glyphRange.lowerBound
    if glyphsBeforeIndicator < 2 {
      // display indicator below, so don't resize the last line fragment.
      readOnlySizeCache.textContainerDidShrinkLastLine = false
    } else {
      // display indicator inline
      lineFragmentRect.size.width = min(lineFragmentRect.width, self.size.width - (sizeForTruncationString.width + readOnlySizeCache.gapBeforeTruncationString))
      readOnlySizeCache.textContainerDidShrinkLastLine = true
    }

    return lineFragmentRect
  }
}
