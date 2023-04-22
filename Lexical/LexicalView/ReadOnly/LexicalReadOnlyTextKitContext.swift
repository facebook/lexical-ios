/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

internal class LexicalReadOnlySizeCache {

  internal enum TruncationStringMode {
    case noTruncation
    case displayedInLastLine
    case displayedUnderLastLine
  }

  var requiredWidth: CGFloat = 0
  var requiredHeight: CGFloat? // nil if auto height
  var measuredTextKitHeight: CGFloat? // the height of rendered text. Will always be less than the targetHeight
  var customTruncationString: String? // set to nil to opt out of custom truncation
  var customTruncationAttributes: [NSAttributedString.Key: Any] = [:]
  var truncationStringMode: TruncationStringMode = .noTruncation // this is the computed truncation mode, not the desired mode
  var extraHeightForTruncationLine: CGFloat = 0 // iff truncationStringMode is displayedUnderLastLine, this is the height needed to add to the main height.
  var cachedTextContainerInsets: UIEdgeInsets = .zero
  var glyphRangeForLastLineFragmentBeforeTruncation: NSRange?
  var glyphRangeForLastLineFragmentAfterTruncation: NSRange?
  var characterRangeForLastLineFragmentBeforeTruncation: NSRange?
  var glyphIndexAtTruncationIndicatorCutPoint: Int? // assuming the truncation indicator is inline, this is where it would be cut.
  var textContainerDidShrinkLastLine: Bool?
  var sizeForTruncationString: CGSize?
  var originForTruncationStringInTextKitCoordinates: CGPoint? // need adding the insets left/top to get it in view coordinates
  var gapBeforeTruncationString: CGFloat = 6.0

  var completeHeightToRender: CGFloat {
    get {
      guard let measuredTextKitHeight else { return 0 }
      var height = measuredTextKitHeight

      // add insets if necessary
      height += cachedTextContainerInsets.top
      height += cachedTextContainerInsets.bottom

      if truncationStringMode == .displayedUnderLastLine {
        height += extraHeightForTruncationLine
      }

      return height
    }
  }

  var completeSizeToRender: CGSize {
    get {
      return CGSize(width: requiredWidth, height: completeHeightToRender)
    }
  }

  var customTruncationRect: CGRect? {
    get {
      guard let origin = originForTruncationStringInTextKitCoordinates,
            let size = sizeForTruncationString else { return nil }
      return CGRect(origin: origin, size: size)
    }
  }
}

@objc public class LexicalReadOnlyTextKitContext: NSObject, Frontend {
  @objc public let layoutManager: LayoutManager
  public let textStorage: TextStorage
  public let textContainer: TextContainer
  let layoutManagerDelegate: LayoutManagerDelegate
  @objc public let editor: Editor

  private var targetHeight: CGFloat? // null if fully auto-height
  internal var sizeCache: LexicalReadOnlySizeCache

  @objc public var truncationString: String?

  @objc weak var attachedView: LexicalReadOnlyView? {
    didSet {
      if attachedView == nil {
        editor.frontendDidUnattachView()
      } else {
        editor.frontendDidAttachView()
      }
    }
  }
  @objc public init(editorConfig: EditorConfig, featureFlags: FeatureFlags) {
    layoutManager = LayoutManager()
    layoutManagerDelegate = LayoutManagerDelegate()
    layoutManager.delegate = layoutManagerDelegate
    textStorage = TextStorage()
    textStorage.addLayoutManager(layoutManager)
    textContainer = TextContainer()
    layoutManager.addTextContainer(textContainer)

    // TEMP
    textContainer.lineBreakMode = .byTruncatingTail

    sizeCache = LexicalReadOnlySizeCache()
    textContainer.readOnlySizeCache = sizeCache
    layoutManager.readOnlySizeCache = sizeCache

    editor = Editor(featureFlags: featureFlags, editorConfig: editorConfig)
    super.init()
    editor.frontend = self
    textStorage.editor = editor
  }

  internal func viewDidLayoutSubviews(viewBounds: CGRect) {
    setTextContainerSize(forWidth: viewBounds.width, maxHeight: self.targetHeight)
  }

  // MARK: - Size cache logistics

  private func createAndPropagateSizeCache() {
    sizeCache = LexicalReadOnlySizeCache()
    textContainer.readOnlySizeCache = sizeCache
    layoutManager.readOnlySizeCache = sizeCache
  }

  // MARK: - Size calculation

  let arbitrarilyLargeHeight: CGFloat = 100000

  @objc public func setTextContainerSizeWithUnlimitedHeight(forWidth width: CGFloat) {
    setTextContainerSize(forWidth: width, maxHeight: nil)
  }

  @objc public func setTextContainerSizeWithTruncation(forWidth width: CGFloat, maximumHeight maxHeight: CGFloat) {
    setTextContainerSize(forWidth: width, maxHeight: maxHeight)
  }

  private func setTextContainerSize(forWidth width: CGFloat, maxHeight: CGFloat?) {
    if sizeCache.requiredWidth == width && sizeCache.requiredHeight == maxHeight {
      return
    }

    createAndPropagateSizeCache()
    sizeCache.requiredWidth = width
    self.targetHeight = maxHeight
    sizeCache.requiredHeight = maxHeight
    sizeCache.customTruncationString = truncationString

    // 1. Set text container size
    let textContainerWidth = width - textContainerInsets.left - textContainerInsets.right
    sizeCache.cachedTextContainerInsets = textContainerInsets
    let textContainerHeight = maxHeight ?? arbitrarilyLargeHeight
    textContainer.size = CGSize(width: textContainerWidth, height: textContainerHeight)

    // we need a full re-lay-out here since size changed.
    layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length), actualCharacterRange: nil)

    // 2. Get the last line fragment rect (pre truncation)
    let glyphRangeForContainer = layoutManager.glyphRange(for: textContainer)
    let lastGlyph = glyphRangeForContainer.upperBound - 1
    var effectiveGlyphRangeForLastLineFragmentPreTruncation = NSRange()
    let lastLineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyph, effectiveRange: &effectiveGlyphRangeForLastLineFragmentPreTruncation)
    sizeCache.glyphRangeForLastLineFragmentBeforeTruncation = effectiveGlyphRangeForLastLineFragmentPreTruncation
    sizeCache.characterRangeForLastLineFragmentBeforeTruncation = layoutManager.characterRange(forGlyphRange: effectiveGlyphRangeForLastLineFragmentPreTruncation, actualGlyphRange: nil)

    // 3. Use the last line fragment rect to derive the used height. This will get replaced if we do truncation!
    sizeCache.measuredTextKitHeight = lastLineFragmentRect.maxY

    // 4. Is there truncation?
    let characterRangeForContainer = layoutManager.characterRange(forGlyphRange: glyphRangeForContainer, actualGlyphRange: nil)
    let isTruncating = self.truncationString != nil && characterRangeForContainer.upperBound < textStorage.string.lengthAsNSString()
    guard isTruncating, let truncationString else {
      return
    }

    // 5. If there's to be truncation, work out size of truncation string
    let truncationAttributes = editor.getTheme().truncationIndicatorAttributes
    let truncationAttributedString = NSAttributedString(string: truncationString, attributes: truncationAttributes)
    let truncationStringRect = truncationAttributedString.boundingRect(with: lastLineFragmentRect.size, options: .usesLineFragmentOrigin, context: nil)
    sizeCache.customTruncationAttributes = truncationAttributes
    sizeCache.sizeForTruncationString = truncationStringRect.size

    // 6. Now we've set the custom truncation string metrics on the size cache, if we re lay out, it should return different size.
    let characterRangeForLastLineFragmentPreTruncation = layoutManager.characterRange(forGlyphRange: effectiveGlyphRangeForLastLineFragmentPreTruncation, actualGlyphRange: nil)
    let truncationStringPlusGapLocation = CGRect(x: lastLineFragmentRect.width - truncationStringRect.width - sizeCache.gapBeforeTruncationString,
                                                 y: lastLineFragmentRect.minY,
                                                 width: truncationStringRect.width + sizeCache.gapBeforeTruncationString,
                                                 height: lastLineFragmentRect.height)
    let truncationCutPoint = layoutManager.glyphIndex(for: CGPoint(x: truncationStringPlusGapLocation.minX, y: lastLineFragmentRect.maxY - 1), in: textContainer, fractionOfDistanceThroughGlyph: nil)
    sizeCache.glyphIndexAtTruncationIndicatorCutPoint = truncationCutPoint

    layoutManager.invalidateLayout(forCharacterRange: characterRangeForLastLineFragmentPreTruncation, actualCharacterRange: nil)
    // at this point, consider the code flow as going to TextContainer.swift

    let newLastLineFragmentUsedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: effectiveGlyphRangeForLastLineFragmentPreTruncation.lowerBound, effectiveRange: nil)

    // Replace the derived text kit height, in case something is different now!
    sizeCache.measuredTextKitHeight = newLastLineFragmentUsedRect.maxY

    // 7. now we detect truncation mode
    if let didShrink = sizeCache.textContainerDidShrinkLastLine, didShrink == true {
      // the line shrunk, so we must be truncating inline
      sizeCache.truncationStringMode = .displayedInLastLine
      sizeCache.originForTruncationStringInTextKitCoordinates = CGPoint(x: newLastLineFragmentUsedRect.maxX + sizeCache.gapBeforeTruncationString, y: newLastLineFragmentUsedRect.maxY - truncationStringRect.height)
    } else {
      // we know we're truncating due to step 4, but the last line seems not to have shrunk, so we must put See More on a new line.
      // To clarify, the shrinking happens in the logic inside TextContainer.swift
      sizeCache.truncationStringMode = .displayedUnderLastLine
      sizeCache.extraHeightForTruncationLine = truncationStringRect.height + sizeCache.gapBeforeTruncationString
      sizeCache.originForTruncationStringInTextKitCoordinates = CGPoint(x: 0, y: newLastLineFragmentUsedRect.maxY + sizeCache.gapBeforeTruncationString)
    }
  }

  @objc public func requiredSize() -> CGSize {
    return sizeCache.completeSizeToRender
  }

  var textLayoutWidth: CGFloat {
    get {
      return textContainer.size.width - 2 * textContainer.lineFragmentPadding
    }
  }

  @objc public var lineFragmentPadding: CGFloat {
    get {
      return self.textContainer.lineFragmentPadding
    }
    set {
      self.textContainer.lineFragmentPadding = newValue
    }
  }

  // MARK: - Frontend

  @objc public var textContainerInsets: UIEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)

  var nativeSelection: NativeSelection {
    NativeSelection()
  }

  var viewForDecoratorSubviews: UIView? {
    return self.attachedView
  }

  var isEmpty: Bool {
    return textStorage.length == 0
  }

  var isUpdatingNativeSelection: Bool = false

  var interceptNextSelectionChangeAndReplaceWithRange: NSRange?

  func moveNativeSelection(type: NativeSelectionModificationType, direction: UITextStorageDirection, granularity: UITextGranularity) {
    // no-op
  }

  func unmarkTextWithoutUpdate() {
    // no-op
  }

  func presentDeveloperFacingError(message: String) {
    // no-op
  }

  func updateNativeSelection(from selection: RangeSelection) throws {
    // no-op
  }

  func setMarkedTextFromReconciler(_ markedText: NSAttributedString, selectedRange: NSRange) {
    // no-op
  }

  func resetSelectedRange() {
    // no-op
  }

  func showPlaceholderText() {
    // no-op
  }

  var isFirstResponder: Bool {
    false
  }

  // MARK: - Drawing

  public func draw(inContext context: CGContext, point: CGPoint = .zero) {
    context.saveGState()
    UIGraphicsPushContext(context)

    let glyphRange = layoutManager.glyphRange(for: textContainer)
    let insetPoint = CGPoint(x: point.x + textContainerInsets.left, y: point.y + textContainerInsets.top)
    layoutManager.drawBackground(forGlyphRange: glyphRange, at: insetPoint)
    layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: insetPoint)

    UIGraphicsPopContext()
    context.restoreGState()
  }
}
