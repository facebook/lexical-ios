// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import UIKit

@objc public class LexicalReadOnlyTextKitContext: NSObject, Frontend {
  @objc public let layoutManager: LayoutManager
  public let textStorage: TextStorage
  public let textContainer: TextContainer
  let layoutManagerDelegate: LayoutManagerDelegate
  @objc public let editor: Editor

  private var targetHeight: CGFloat? // null if fully auto-height
  private var snapToPreviousLineLeeway: CGFloat = 0.0

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

    editor = Editor(featureFlags: featureFlags, editorConfig: editorConfig)
    super.init()
    editor.frontend = self
    textStorage.editor = editor
  }

  internal func viewDidLayoutSubviews(viewBounds: CGRect) {
    // check if width has changed. Only resize the text container if it has.
    let existingWidth = textContainer.size.width + textContainerInsets.left + textContainerInsets.right
    if existingWidth != viewBounds.width {
      if let targetHeight = targetHeight {
        setTextContainerSize(forWidth: viewBounds.width, targetHeight: targetHeight, snapToPreviousLineLeeway: snapToPreviousLineLeeway)
      } else {
        setTextContainerSize(forWidth: viewBounds.width)
      }
    }
  }

  @objc public func setTextContainerSize(forWidth width: CGFloat) {
    // reset any fixed maximum height
    self.targetHeight = nil
    self.snapToPreviousLineLeeway = 0.0
    layoutManager.activeTruncationMode = .noTruncation

    let size = CGSize(width: width - textContainerInsets.left - textContainerInsets.right, height: 1000000)
    if textContainer.size != size {
      textContainer.size = size
    }
  }

  @objc public func setTextContainerSize(forWidth width: CGFloat, targetHeight: CGFloat, snapToPreviousLineLeeway: CGFloat) {
    // 1. set text container to the size with maximum height
    setTextContainerSize(forWidth: width)

    // cache the target height in case we have to re-lay-out
    // (we do this after calling setTextContainerSize(forWidth:), because that method will clear these variables.)
    self.targetHeight = targetHeight
    self.snapToPreviousLineLeeway = snapToPreviousLineLeeway

    // 2. get line fragment that contains the target height
    var previousLineFragmentRect: CGRect = CGRect.null
    let targetTextContainerHeight = targetHeight - textContainerInsets.top - textContainerInsets.bottom

    var foundOverflowLFR = false
    layoutManager.ensureLayout(for: textContainer)
    layoutManager.enumerateLineFragments(forGlyphRange: layoutManager.glyphRange(for: textContainer)) { currentLineFragmentRect, usedRect, inTextContainer, glyphRange, stopPointer in
      // Check if target height was inside this line
      // (but only if there's a previous line fragment rect -- we always want to display at least one line, even if it's a large image!)
      if currentLineFragmentRect.maxY > targetTextContainerHeight && !previousLineFragmentRect.isNull {
        foundOverflowLFR = true
        stopPointer.initialize(to: true)
        return
      }
      previousLineFragmentRect = currentLineFragmentRect
    }

    if foundOverflowLFR == false {
      layoutManager.activeTruncationMode = .noTruncation
      textContainer.size = CGSize(width: width, height: layoutManager.usedRect(for: textContainer).height)
      // leave the height at whatever we set in step 1, because everything fits.
      return
    }

    let prevLineFragmentMaxY = previousLineFragmentRect.maxY
    var targetTextContainerSize = CGSize.zero

    // 3. For now we're snapping to the previous height always (ignoring the leeway parameter).
    // Doing otherwise was causing some obscure bugs.
    targetTextContainerSize = CGSize(width: width - textContainerInsets.left - textContainerInsets.right, height: prevLineFragmentMaxY + textContainerInsets.top + textContainerInsets.bottom)

    textContainer.size = targetTextContainerSize
    layoutManager.activeTruncationMode = .truncateLine(previousLineFragmentRect)
  }

  @objc public func requiredSize() -> CGSize {
    // If we're doing truncation, use the truncation location for height. Otherwise derive it from layout manager.

    var textContainerMaxY: CGFloat
    if case .truncateLine(let truncationRect) = layoutManager.activeTruncationMode {
      textContainerMaxY = truncationRect.maxY
    } else {
      textContainerMaxY = layoutManager.usedRect(for: textContainer).maxY
    }

    return CGSize(width: textContainer.size.width + textContainerInsets.left + textContainerInsets.right,
                  height: textContainerMaxY + textContainerInsets.top + textContainerInsets.bottom)
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

    let rect = layoutManager.usedRect(for: textContainer)
    let glyphRange = layoutManager.glyphRange(forBoundingRectWithoutAdditionalLayout: rect, in: textContainer)
    let insetPoint = CGPoint(x: point.x + textContainerInsets.left, y: point.y + textContainerInsets.top)
    layoutManager.drawBackground(forGlyphRange: glyphRange, at: insetPoint)
    layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: insetPoint)

    UIGraphicsPopContext()
    context.restoreGState()
  }
}
