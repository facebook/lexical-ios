/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

class LayoutManagerDelegate: NSObject, NSLayoutManagerDelegate {
  func layoutManager(
    _ layoutManager: NSLayoutManager,
    shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
    properties: UnsafePointer<NSLayoutManager.GlyphProperty>,
    characterIndexes: UnsafePointer<Int>,
    font: UIFont,
    forGlyphRange glyphRange: NSRange
  ) -> Int {

    guard let textStorage = layoutManager.textStorage else {
      fatalError()
    }

    let incomingGlyphsLength = glyphRange.length
    let firstCharIndex = characterIndexes[0]
    let lastCharIndex = characterIndexes[glyphRange.length - 1]
    let charactersRange = NSRange(location: firstCharIndex, length: lastCharIndex - firstCharIndex + 1)

    var operationRanges: [(range: NSRange, operation: TextTransform)] = []
    var hasOperations = false

    textStorage.enumerateAttribute(.textTransform, in: charactersRange, options: []) { attributeValue, range, _ in
      let transform = TextTransform(rawValue: attributeValue as? String ?? TextTransform.none.rawValue) ?? .none
      operationRanges.append((range: range, operation: transform))
      if transform != .none {
        hasOperations = true
      }
    }

    // bail if no operations. Returning 0 tells NSLayoutManager to use its default implementation
    if hasOperations == false {
      return 0
    }

    var operationResults: [(glyphs: [CGGlyph], properties: [NSLayoutManager.GlyphProperty], characterIndexes: [Int])] = []
    var bufferLength = 0
    var locationWithinIncomingGlyphsRange = 0

    let textStorageString = textStorage.string as NSString
    let ctFont = font as CTFont

    for operationRange in operationRanges {
      // derive the end location for the current string range in terms of the passed in glyph range
      var glyphSubrangeEnd = locationWithinIncomingGlyphsRange + operationRange.range.length // start the search here, it can't be less than that
      while glyphSubrangeEnd <= incomingGlyphsLength {
        let nextCharIndex = characterIndexes[glyphSubrangeEnd + 1]
        if !operationRange.range.contains(nextCharIndex) {
          break
        }
        glyphSubrangeEnd += 1
      }
      let glyphSubrangeLength = glyphSubrangeEnd - locationWithinIncomingGlyphsRange

      if operationRange.operation == .none {
        // copy the original glyphs from the input to this method
        let newGlyphs = Array(UnsafeBufferPointer(start: glyphs + locationWithinIncomingGlyphsRange, count: glyphSubrangeLength))
        let newProperties = Array(UnsafeBufferPointer(start: properties + locationWithinIncomingGlyphsRange, count: glyphSubrangeLength))
        let newCharIndexes = Array(UnsafeBufferPointer(start: characterIndexes + locationWithinIncomingGlyphsRange, count: glyphSubrangeLength))

        operationResults.append((glyphs: newGlyphs, properties: newProperties, characterIndexes: newCharIndexes))
        bufferLength += glyphSubrangeLength
      } else {
        // We now have a transform to do. Do it one character at a time in order to keep our character mapping accurate.
        textStorageString.enumerateSubstrings(in: operationRange.range, options: .byComposedCharacterSequences) { substring, substringRange, enclosingRange, _ in
          guard let substring else {
            return
          }

          // first check if we are one half of a composed character
          let composedNormalisedRange = textStorageString.rangeOfComposedCharacterSequence(at: substringRange.location)
          if composedNormalisedRange != substringRange {
            // for this case, we can't upper or lower case _half_ a character.
            operationResults.append((glyphs: [CGGlyph](repeating: CGGlyph(0), count: substringRange.length),
                                     properties: [NSLayoutManager.GlyphProperty](repeating: .null, count: substringRange.length),
                                     characterIndexes: Array(substringRange.location...(substringRange.location + substringRange.length))))
            bufferLength += substringRange.length
            return
          }

          // upper case the character
          let modifiedSubstring = operationRange.operation == .lowercase ? substring.lowercased() : substring.uppercased()

          // iterate through this _new_ string, in case upper casing it resulted in more than one composed character
          (modifiedSubstring as NSString).enumerateSubstrings(in: NSRange(location: 0, length: modifiedSubstring.lengthAsNSString()),
                                                              options: .byComposedCharacterSequences) { innerSubstring, innerSubstringRange, innerEnclosingRange, _ in
            guard let innerSubstring else {
              return
            }

            // Generate glyphs for the character
            let utf16 = Array(innerSubstring.utf16)
            var newGlyphs = [CGGlyph](repeating: 0, count: utf16.count)
            CTFontGetGlyphsForCharacters(ctFont, utf16, &newGlyphs, utf16.count) // if failure, glyph array will be empty as desired

            // build up our best guess at the glyph properties!
            var newProperties = [NSLayoutManager.GlyphProperty](repeating: .init(rawValue: 0), count: utf16.count)
            if let firstChar = innerSubstring.first, firstChar.isWhitespace {
              // checking the first char for whitespace is a reasonable approximation, because we don't expect there to be more than one character here
              newProperties = [NSLayoutManager.GlyphProperty](repeating: .elastic, count: utf16.count)
            }
            if utf16.count > 1 {
              for i in 1..<utf16.count {
                // Since we're expecting one character here (even in terms of our modified capitalised string), any extra points will be non base characters.
                newProperties[i] = .nonBaseCharacter
              }
            }

            // fill in character indexes incrementing based on substringRange (which is in terms of original string locations).
            var newCharIndexes = [Int](repeating: 0, count: newGlyphs.count)
            for i in 0..<substringRange.length {
              newCharIndexes[i] = i + substringRange.location
            }
            // If we have extra glyphs, repeat the last character index.
            if substringRange.length < newGlyphs.count {
              for i in substringRange.length..<newGlyphs.count {
                newCharIndexes[i] = substringRange.upperBound
              }
            }

            operationResults.append((glyphs: newGlyphs, properties: newProperties, characterIndexes: newCharIndexes))
            bufferLength += newGlyphs.count
          }
        }
      }
      locationWithinIncomingGlyphsRange += glyphSubrangeLength
    }

    let sumGlyphs = operationResults.flatMap { $0.glyphs }
    let sumProps = operationResults.flatMap { $0.properties }
    let sumCharacterIndexes = operationResults.flatMap { $0.characterIndexes }

    var fail = false
    sumGlyphs.withUnsafeBufferPointer { sumGlyphsBuffer in
      sumProps.withUnsafeBufferPointer { sumPropsBuffer in
        sumCharacterIndexes.withUnsafeBufferPointer { sumCharsBuffer in
          guard let sumGlyphsBaseAddress = sumGlyphsBuffer.baseAddress,
                let sumPropsBaseAddress = sumPropsBuffer.baseAddress,
                let sumCharsBaseAddress = sumCharsBuffer.baseAddress else {
            fail = true
            return
          }
          layoutManager.setGlyphs(sumGlyphsBaseAddress, properties: sumPropsBaseAddress, characterIndexes: sumCharsBaseAddress, font: font, forGlyphRange: NSRange(location: glyphRange.location, length: bufferLength))
        }
      }
    }

    return fail == true ? 0 : bufferLength
  }

  // cannot use glyphrange for textcontainer, or infinite loop
  func layoutManager(
    _ layoutManager: NSLayoutManager,
    shouldSetLineFragmentRect lineFragmentRectPointer: UnsafeMutablePointer<CGRect>,
    lineFragmentUsedRect lineFragmentUsedRectPointer: UnsafeMutablePointer<CGRect>,
    baselineOffset: UnsafeMutablePointer<CGFloat>,
    in textContainer: NSTextContainer,
    forGlyphRange glyphRange: NSRange
  ) -> Bool {
    // This method only sets the location we're going to draw the custom truncation string.
    // See TextContainer.swift for the thing that shortens the line fragments.

    guard let layoutManager = layoutManager as? LayoutManager,
          case let .truncateLine(desiredTruncationLine) = layoutManager.activeTruncationMode,
          let truncationString = layoutManager.customTruncationString
    else {
      return false
    }

    let lineFragmentRect: CGRect = lineFragmentRectPointer.pointee
    let lineFragmentUsedRect: CGRect = lineFragmentUsedRectPointer.pointee

    // check if we're looking at the last line
    guard lineFragmentRect.minY == desiredTruncationLine.minY else {
      return false
    }

    // we have a match, and should truncate. Shrink the line by enough room to display our truncation string.
    let truncationAttributes = layoutManager.editor?.getTheme().truncationIndicatorAttributes ?? [:]
    let truncationAttributedString = NSAttributedString(string: truncationString, attributes: truncationAttributes)

    // assuming we don't make the line fragment rect bigger in order to fit the truncation string
    let requiredRect = truncationAttributedString.boundingRect(with: lineFragmentRect.size, options: .usesLineFragmentOrigin, context: nil)

    // TODO: derive this somehow
    // (currently using this heuristic to detect 'blank line' and add no spacing)
    let xLoc = (lineFragmentUsedRect.width < 6)
      ? 0.0
      : lineFragmentUsedRect.minX + lineFragmentUsedRect.width + 6.0 // the '6.0' is the spacing

    layoutManager.customTruncationDrawingRect = CGRect(x: xLoc,
                                                       y: lineFragmentUsedRect.minY + (lineFragmentUsedRect.height - requiredRect.height),
                                                       width: requiredRect.width,
                                                       height: requiredRect.height)

    // we didn't change anything so always return false
    return false
  }
}
