/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import UIKit

internal enum ActiveTruncationMode {
  case noTruncation
  case truncateLine(CGRect) // the rect is the pre-calculated last line. See calculations in LexicalReadOnlyView
}

public class LayoutManager: NSLayoutManager {
  internal weak var editor: Editor? {
    get {
      if let textStorage = textStorage as? TextStorage {
        return textStorage.editor
      }
      return nil
    }
  }

  // set by the Lexical consumer
  @objc public var customTruncationString: String? = "See More"

  // set by the ReadOnlyView
  internal var activeTruncationMode: ActiveTruncationMode = .noTruncation

  // set by layout manager delegate during layout process
  internal var customTruncationDrawingRect: CGRect?

  private var customDrawingBackground: [NSAttributedString.Key: Editor.CustomDrawingHandlerInfo] {
    get {
      return editor?.customDrawingBackground ?? [:]
    }
  }
  private var customDrawingText: [NSAttributedString.Key: Editor.CustomDrawingHandlerInfo] {
    get {
      return editor?.customDrawingText ?? [:]
    }
  }

  override public func drawBackground(forGlyphRange drawingGlyphRange: NSRange, at origin: CGPoint) {
    super.drawBackground(forGlyphRange: drawingGlyphRange, at: origin)
    draw(forGlyphRange: drawingGlyphRange, at: origin, handlers: customDrawingBackground)
  }

  override public func drawGlyphs(forGlyphRange drawingGlyphRange: NSRange, at origin: CGPoint) {
    super.drawGlyphs(forGlyphRange: drawingGlyphRange, at: origin)
    draw(forGlyphRange: drawingGlyphRange, at: origin, handlers: customDrawingText)
    drawCustomTruncationIfNeeded(forGlyphRange: drawingGlyphRange, at: origin)
  }

  private func drawCustomTruncationIfNeeded(forGlyphRange drawingGlyphRange: NSRange, at origin: CGPoint) {
    guard let customTruncationString = customTruncationString,
          let customTruncationDrawingRect = customTruncationDrawingRect,
          let attributes = editor?.getTheme().truncationIndicatorAttributes else { return }

    let modifiedDrawingRect = customTruncationDrawingRect.offsetBy(dx: origin.x, dy: origin.y)
    let attributedString = NSAttributedString(string: customTruncationString, attributes: attributes)
    attributedString.draw(in: modifiedDrawingRect)
  }

  private func draw(forGlyphRange drawingGlyphRange: NSRange, at origin: CGPoint, handlers: [NSAttributedString.Key: Editor.CustomDrawingHandlerInfo]) {
    let characterRange = characterRange(forGlyphRange: drawingGlyphRange, actualGlyphRange: nil)
    guard let textStorage = textStorage as? TextStorage else {
      return
    }

    handlers.forEach { attribute, value in
      let handler = value.customDrawingHandler
      let granularity = value.granularity

      textStorage.enumerateAttribute(attribute, in: characterRange) { value, attributeRunRange, _ in
        guard let value = value else {
          // we only trigger when there is a non-nil value
          return
        }
        let glyphRangeForAttributeRun = glyphRange(forCharacterRange: attributeRunRange, actualCharacterRange: nil)
        ensureLayout(forGlyphRange: glyphRangeForAttributeRun)

        switch granularity {
        case .characterRuns:
          enumerateLineFragments(forGlyphRange: glyphRangeForAttributeRun) { rect, usedRect, textContainer, glyphRangeForGlyphRun, _ in
            let intersectionRange = NSIntersectionRange(glyphRangeForAttributeRun, glyphRangeForGlyphRun)
            let charRangeToDraw = self.characterRange(forGlyphRange: intersectionRange, actualGlyphRange: nil)
            let glyphBoundingRect = self.boundingRect(forGlyphRange: intersectionRange, in: textContainer)
            handler(attribute, value, self, attributeRunRange, charRangeToDraw, intersectionRange, glyphBoundingRect.offsetBy(dx: origin.x, dy: origin.y), rect.offsetBy(dx: origin.x, dy: origin.y))
          }
        case .singleParagraph:
          let paraGroupRange = textStorage.mutableString.paragraphRange(for: attributeRunRange)
          (textStorage.string as NSString).enumerateSubstrings(in: paraGroupRange, options: .byParagraphs) { substring, substringRange, enclosingRange, _ in
            guard substringRange.length >= 1 else { return }
            let glyphRangeForParagraph = self.glyphRange(forCharacterRange: substringRange, actualCharacterRange: nil)
            let firstCharLineFragment = self.lineFragmentRect(forGlyphAt: glyphRangeForParagraph.location, effectiveRange: nil)
            let lastCharLineFragment = self.lineFragmentRect(forGlyphAt: glyphRangeForParagraph.upperBound - 1, effectiveRange: nil)
            let containingRect = firstCharLineFragment.union(lastCharLineFragment)
            handler(attribute, value, self, attributeRunRange, substringRange, glyphRangeForParagraph, containingRect.offsetBy(dx: origin.x, dy: origin.y), firstCharLineFragment.offsetBy(dx: origin.x, dy: origin.y))
          }
        case .contiguousParagraphs:
          let paraGroupRange = textStorage.mutableString.paragraphRange(for: attributeRunRange)
          guard paraGroupRange.length >= 1 else { return }
          let glyphRangeForParagraphs = self.glyphRange(forCharacterRange: paraGroupRange, actualCharacterRange: nil)
          let firstCharLineFragment = self.lineFragmentRect(forGlyphAt: glyphRangeForParagraphs.location, effectiveRange: nil)

          let lastCharLineFragment = (paraGroupRange.upperBound == textStorage.length && self.extraLineFragmentRect.height > 0)
            ? self.extraLineFragmentRect
            : self.lineFragmentRect(forGlyphAt: glyphRangeForParagraphs.upperBound - 1, effectiveRange: nil)

          var containingRect = firstCharLineFragment.union(lastCharLineFragment).offsetBy(dx: origin.x, dy: origin.y)

          // If there are block styles, subtract the margin here. TODO: support nested or overlapping block element styles
          if let blockStyle = textStorage.attribute(.appliedBlockLevelStyles_internal, at: paraGroupRange.location, effectiveRange: nil) as? BlockLevelAttributes {
            // first check to see if we should apply top margin.
            // Logic is, the margin size is taken into account in the fragment rect height by means of paragraphSpacingBefore... however, TextKit tries to be clever and omits that spacing
            // if it's the first paragraph.
            if paraGroupRange.location > 0 {
              containingRect.origin.y += blockStyle.marginTop
              containingRect.size.height -= blockStyle.marginTop
            }
            // next check for bottom margin
            if paraGroupRange.location + paraGroupRange.length < textStorage.string.lengthAsNSString() {
              containingRect.size.height -= blockStyle.marginBottom
            }
          }

          handler(attribute, value, self, attributeRunRange, paraGroupRange, glyphRangeForParagraphs, containingRect, firstCharLineFragment.offsetBy(dx: origin.x, dy: origin.y))
        }
      }
    }
  }

  override public func attachmentSize(forGlyphAt glyphIndex: Int) -> CGSize {
    updateDecoratorSize(forGlyphAt: glyphIndex)
    return super.attachmentSize(forGlyphAt: glyphIndex)
  }

  private func updateDecoratorSize(forGlyphAt glyphIndex: Int) {
    guard let textContainer = textContainers.first, let textStorage = textStorage else {
      editor?.log(.TextView, .warning, "called with no container or storage")
      return
    }

    let glyphIsInTextContainer = NSLocationInRange(glyphIndex, glyphRange(for: textContainer))

    var glyphBoundingRect: CGRect = .zero
    var shouldHideView: Bool = true // this will be set to false if we get a non-empty bounding rect

    if glyphIsInTextContainer {
      ensureLayout(forGlyphRange: NSRange(location: glyphIndex, length: 1))
      glyphBoundingRect = boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
      shouldHideView = glyphBoundingRect.isEmpty // if the decorator is outside the text container, the bounding rect will be empty
    }

    let characterIndex = characterIndexForGlyph(at: glyphIndex)
    var attribute: TextAttachment?

    if NSLocationInRange(characterIndex, NSRange(location: 0, length: textStorage.length)) {
      attribute = textStorage.attribute(.attachment, at: characterIndex, effectiveRange: nil) as? TextAttachment
    }

    guard let attr = attribute, let key = attr.key, let editor = attr.editor else {
      editor?.log(.TextView, .warning, "called with no attachment")
      return
    }

    let textContainerInset = self.editor?.frontend?.textContainerInsets ?? UIEdgeInsets.zero

    try? editor.read {
      guard let decoratorView = decoratorView(forKey: key, createIfNecessary: !shouldHideView),
            let decoratorNode = getNodeByKey(key: key) as? DecoratorNode else {
        editor.log(.TextView, .warning, "create decorator view failed")
        return
      }

      if shouldHideView {
        decoratorView.isHidden = true
        return
      }

      // we have a valid location, make sure view is not hidden
      decoratorView.isHidden = false

      var decoratorOrigin = glyphBoundingRect.offsetBy(dx: textContainerInset.left, dy: textContainerInset.top).origin // top left

      let textLayoutWidth = editor.frontend?.textLayoutWidth ?? CGFloat(0)
      let decoratorSize = decoratorNode.sizeForDecoratorView(textViewWidth: textLayoutWidth)

      decoratorOrigin.y += (glyphBoundingRect.height - decoratorSize.height) // bottom left now!

      decoratorView.frame = CGRect(origin: decoratorOrigin, size: decoratorSize)
    }
  }

  @available(iOS 13.0, *)
  override public func showCGGlyphs(_ glyphs: UnsafePointer<CGGlyph>, positions: UnsafePointer<CGPoint>, count glyphCount: Int, font: UIFont, textMatrix: CGAffineTransform, attributes: [NSAttributedString.Key: Any] = [:], in context: CGContext) {

    // fix for links with custom colour -- UIKit has trouble with this!
    if attributes[.link] != nil, let colorAttr = attributes[.foregroundColor] as? UIColor {
      context.setFillColor(colorAttr.cgColor)
    }

    super.showCGGlyphs(glyphs, positions: positions, count: glyphCount, font: font, textMatrix: textMatrix, attributes: attributes, in: context)
  }
}
