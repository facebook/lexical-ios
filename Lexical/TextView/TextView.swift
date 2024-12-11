/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import MobileCoreServices
import UIKit
import UniformTypeIdentifiers

protocol LexicalTextViewDelegate: NSObjectProtocol {
  func textViewDidBeginEditing(textView: TextView)
  func textViewDidEndEditing(textView: TextView)
  func textViewShouldChangeText(_ textView: UITextView, range: NSRange, replacementText text: String) -> Bool
  func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool
}

/// Lexical's subclass of UITextView. Note that using this can be dangerous, if you make changes that Lexical does not expect.
@objc public class TextView: UITextView {
  let editor: Editor

  internal let pasteboard = UIPasteboard.general
  internal let pasteboardIdentifier = "x-lexical-nodes"
  internal var isUpdatingNativeSelection = false
  internal var layoutManagerDelegate: LayoutManagerDelegate

  // This is to work around a UIKit issue where, in situations like autocomplete, UIKit changes our selection via
  // private methods, and the first time we find out is when our delegate method is called. @amyworrall
  internal var interceptNextSelectionChangeAndReplaceWithRange: NSRange?
  weak var lexicalDelegate: LexicalTextViewDelegate?
  private var placeholderLabel: UILabel

  private let useInputDelegateProxy: Bool
  private let inputDelegateProxy: InputDelegateProxy

  fileprivate var textViewDelegate: TextViewDelegate

  // MARK: - Init

  init(editorConfig: EditorConfig, featureFlags: FeatureFlags) {
    let textStorage = TextStorage()
    let layoutManager = LayoutManager()
    layoutManagerDelegate = LayoutManagerDelegate()
    layoutManager.delegate = layoutManagerDelegate

    let textContainer = TextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    textContainer.widthTracksTextView = true

    layoutManager.addTextContainer(textContainer)
    textStorage.addLayoutManager(layoutManager)

    var reconcilerSanityCheck = featureFlags.reconcilerSanityCheck

    #if targetEnvironment(simulator)
    reconcilerSanityCheck = false
    #endif

    editor = Editor(
      featureFlags: FeatureFlags(reconcilerSanityCheck: reconcilerSanityCheck),
      editorConfig: editorConfig)
    textStorage.editor = editor
    placeholderLabel = UILabel(frame: .zero)

    useInputDelegateProxy = featureFlags.proxyTextViewInputDelegate
    inputDelegateProxy = InputDelegateProxy()
    textViewDelegate = TextViewDelegate(editor: editor)

    super.init(frame: .zero, textContainer: textContainer)

    if useInputDelegateProxy {
      inputDelegateProxy.targetInputDelegate = self.inputDelegate
      super.inputDelegate = inputDelegateProxy
    }

    delegate = textViewDelegate
    textContainerInset = UIEdgeInsets(top: 8.0, left: 5.0, bottom: 8.0, right: 5.0)

    setUpPlaceholderLabel()
    registerRichText(editor: editor)
  }

  /// This init method is used for unit tests
  convenience init() {
    self.init(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("\(#function) has not been implemented")
  }

  override public func layoutSubviews() {
    super.layoutSubviews()

    placeholderLabel.frame.origin = CGPoint(x: textContainer.lineFragmentPadding * 1.5 + textContainerInset.left, y: textContainerInset.top)
    placeholderLabel.sizeToFit()
  }

  override public var inputDelegate: UITextInputDelegate? {
    get {
      if useInputDelegateProxy {
        return inputDelegateProxy.targetInputDelegate
      } else {
        return super.inputDelegate
      }
    }
    set {
      if useInputDelegateProxy {
        inputDelegateProxy.targetInputDelegate = newValue
      } else {
        super.inputDelegate = newValue
      }
    }
  }

  public override func caretRect(for position: UITextPosition) -> CGRect {
    let originalRect = super.caretRect(for: position)
    return CaretAndSelectionRectsAdjuster.adjustCaretRect(originalRect, for: position, in: self)
  }

  override public func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
    let originalRects = super.selectionRects(for: range)
    return CaretAndSelectionRectsAdjuster.adjustSelectionRects(originalRects, for: range, in: self)
  }

  // MARK: - Incoming events

  override public func deleteBackward() {
    editor.log(.UITextView, .verbose, "deleteBackward()")

    let previousSelectedRange = selectedRange

    inputDelegateProxy.isSuspended = true // do not send selection changes during deleteBackwards, to not confuse third party keyboards
    defer {
      inputDelegateProxy.isSuspended = false
    }

    editor.dispatchCommand(type: .deleteCharacter, payload: true)

    if previousSelectedRange.length > 0 {
      // Expect new selection to be on the start of selection
      if selectedRange.location != previousSelectedRange.location || selectedRange.length != 0 {
        inputDelegateProxy.sendSelectionChangedIgnoringSuspended(self)
      }
    } else {
      // Expect new selection to be somewhere before selection -- we could calculate this by considering
      // unicode characters, but it would be complex. Let's do a best effort, since this situation is rare anyway.
      if selectedRange.length != 0 || selectedRange.location >= previousSelectedRange.location {
        inputDelegateProxy.sendSelectionChangedIgnoringSuspended(self)
      }
    }

    resetTypingAttributes(for: selectedRange)
  }

  public func resetTypingAttributes(for selectedRange: NSRange) {
    do {
      try editor.read {
        guard let editor = getActiveEditor(),
              let point = try pointAtStringLocation(
                selectedRange.location,
                searchDirection: .forward,
                rangeCache: editor.rangeCache)
        else {
          return
        }

        let node = try point.getNode()
        resetTypingAttributes(for: node)
      }
    } catch {
      print("Failed resetting typing attributes: \(error)")
    }
  }

  public func resetTypingAttributes(for selectedNode: Node) {
    let attributes = AttributeUtils.attributedStringStyles(
      from: selectedNode,
      state: editor.getEditorState(),
      theme: editor.getTheme()
    )
    typingAttributes = attributes
  }

  override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(paste(_:)) {
      if pasteboard.hasStrings {
        return true
      } else if !(pasteboard.data(forPasteboardType: LexicalConstants.pasteboardIdentifier)?.isEmpty ?? true) {
        return true
      } else if #available(iOS 14.0, *) {
        if !(pasteboard.data(forPasteboardType: (UTType.utf8PlainText.identifier))?.isEmpty ?? true) {
          return true
        }
      } else {
        if !(pasteboard.data(forPasteboardType: (kUTTypeUTF8PlainText as String))?.isEmpty ?? true) {
          return true
        }
      }
      return super.canPerformAction(action, withSender: sender)
    } else {
      return super.canPerformAction(action, withSender: sender)
    }
  }

  override public func copy(_ sender: Any?) {
    editor.dispatchCommand(type: .copy, payload: pasteboard)
  }

  override public func cut(_ sender: Any?) {
    editor.dispatchCommand(type: .cut, payload: pasteboard)
  }

  override public func paste(_ sender: Any?) {
    editor.dispatchCommand(type: .paste, payload: pasteboard)
  }

  override public func insertText(_ text: String) {
    editor.log(.UITextView, .verbose, "Text view selected range \(String(describing: self.selectedRange))")

    let expectedSelectionLocation = selectedRange.location + text.lengthAsNSString()

    inputDelegateProxy.isSuspended = true // do not send selection changes during insertText, to not confuse third party keyboards
    defer {
      inputDelegateProxy.isSuspended = false
    }

    guard let textStorage = textStorage as? TextStorage else {
      // This should never happen, we will always have a custom text storage.
      editor.log(.TextView, .error, "Missing custom text storage")
      return
    }

    textStorage.mode = TextStorageEditingMode.controllerMode
    editor.dispatchCommand(type: .insertText, payload: text)
    textStorage.mode = TextStorageEditingMode.none

    // check if we need to send a selectionChanged (i.e. something unexpected happened)
    if selectedRange.length != 0 || selectedRange.location != expectedSelectionLocation {
      inputDelegateProxy.sendSelectionChangedIgnoringSuspended(self)
    }
  }

  // MARK: Marked text

  override public func setAttributedMarkedText(_ markedText: NSAttributedString?, selectedRange: NSRange) {
    editor.log(.UITextView, .verbose)
    if let markedText {
      setMarkedTextInternal(markedText.string, selectedRange: selectedRange)
    } else {
      unmarkText()
    }
  }

  override public func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
    editor.log(.UITextView, .verbose)
    if let markedText {
      setMarkedTextInternal(markedText, selectedRange: selectedRange)
    } else {
      unmarkText()
    }
  }

  private func setMarkedTextInternal(_ markedText: String, selectedRange: NSRange) {
    editor.log(.TextView, .verbose)
    guard let textStorage = textStorage as? TextStorage else {
      // This should never happen, we will always have a custom text storage.
      editor.log(.TextView, .error, "Missing custom text storage")
      super.setMarkedText(markedText, selectedRange: selectedRange)
      return
    }

    if markedText.isEmpty, let markedRange = editor.getNativeSelection().markedRange {
      textStorage.replaceCharacters(in: markedRange, with: "")
      return
    }

    let markedTextOperation = MarkedTextOperation(createMarkedText: true,
                                                  selectionRangeToReplace: editor.getNativeSelection().markedRange ?? self.selectedRange,
                                                  markedTextString: markedText,
                                                  markedTextInternalSelection: selectedRange)

    let behaviourModificationMode = UpdateBehaviourModificationMode(suppressReconcilingSelection: true, suppressSanityCheck: true, markedTextOperation: markedTextOperation)

    textStorage.mode = TextStorageEditingMode.controllerMode
    defer {
      textStorage.mode = TextStorageEditingMode.none
    }
    do {
      // set composition key
      try editor.read {
        guard let selection = try getSelection() as? RangeSelection else {
          editor.log(.TextView, .error, "Could not get selection in setMarkedTextInternal()")
          throw LexicalError.invariantViolation("should have selection when starting marked text")
        }

        editor.compositionKey = selection.anchor.key
      }

      // insert text
      try onInsertTextFromUITextView(text: markedText, editor: editor, updateMode: behaviourModificationMode)
    } catch {
      let language = textInputMode?.primaryLanguage
      editor.log(.TextView, .error, "exception thrown, lang \(String(describing: language)): \(String(describing: error))")
      unmarkTextWithoutUpdate()
      return
    }
  }

  internal func setMarkedTextFromReconciler(_ markedText: NSAttributedString, selectedRange: NSRange) {
    editor.log(.TextView, .verbose)
    isUpdatingNativeSelection = true
    super.setAttributedMarkedText(markedText, selectedRange: selectedRange)
    interceptNextSelectionChangeAndReplaceWithRange = nil
    onSelectionChange(editor: editor)
    isUpdatingNativeSelection = false
    editor.compositionKey = nil
    showPlaceholderText()
  }

  override public func unmarkText() {
    editor.log(.UITextView, .verbose)
    let previousMarkedRange = editor.getNativeSelection().markedRange
    let oldIsUpdatingNative = isUpdatingNativeSelection
    isUpdatingNativeSelection = true
    super.unmarkText()
    isUpdatingNativeSelection = oldIsUpdatingNative
    if let previousMarkedRange {
      // find all nodes in selection. Mark dirty. Reconcile. This should correct all the attributes to be what we expect.
      do {
        try editor.update {
          guard let anchor = try pointAtStringLocation(previousMarkedRange.location, searchDirection: .forward, rangeCache: editor.rangeCache),
                let focus = try pointAtStringLocation(previousMarkedRange.location + previousMarkedRange.length, searchDirection: .forward, rangeCache: editor.rangeCache) else {
            return
          }

          let markedRangeSelection = RangeSelection(anchor: anchor, focus: focus, format: TextFormat())
          _ = try markedRangeSelection.getNodes().map { node in
            internallyMarkNodeAsDirty(node: node, cause: .userInitiated)
          }

          editor.compositionKey = nil
        }
      } catch {}
    }
  }

  internal func unmarkTextWithoutUpdate() {
    editor.log(.TextView, .verbose)
    super.unmarkText()
  }

  // MARK: - Lexical internal

  internal func presentDeveloperFacingError(message: String) {
    let alert = UIAlertController(title: "Lexical Error", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
    if let rootViewController = self.window?.rootViewController {
      rootViewController.present(alert, animated: true, completion: nil)
    }
  }

  internal func updateNativeSelection(from selection: RangeSelection) throws {
    isUpdatingNativeSelection = true
    defer { isUpdatingNativeSelection = false }
    let nativeSelection = try createNativeSelection(from: selection, editor: editor)

    if let range = nativeSelection.range {
      selectedRange = range
    }
  }

  internal func resetSelectedRange() {
    selectedRange = NSRange(location: 0, length: 0)
  }

  func defaultClearEditor() throws {
    editor.resetEditor(pendingEditorState: nil)
    editor.dispatchCommand(type: .clearEditor)
  }

  public func setPlaceholderText(_ text: String, textColor: UIColor, font: UIFont) {
    placeholderLabel.text = text
    placeholderLabel.textColor = textColor
    placeholderLabel.font = font
    self.font = font

    showPlaceholderText()
  }

  func showPlaceholderText() {
    var shouldShow = false
    do {
      try editor.read {
        guard let root = getRoot() else { return }
        shouldShow = root.getTextContentSize() == 0
      }
      if !shouldShow {
        hidePlaceholderLabel()
        return
      }
      try editor.read {
        if canShowPlaceholder(isComposing: editor.isComposing()) {
          placeholderLabel.isHidden = false
          layoutIfNeeded()
        }
      }
    } catch {}
  }

  // MARK: - Private

  private func setUpPlaceholderLabel() {
    placeholderLabel.backgroundColor = .clear
    placeholderLabel.isHidden = true
    placeholderLabel.isAccessibilityElement = false
    placeholderLabel.numberOfLines = 1
    addSubview(placeholderLabel)
  }

  fileprivate func hidePlaceholderLabel() {
    placeholderLabel.isHidden = true
  }

  override public func becomeFirstResponder() -> Bool {
    let r = super.becomeFirstResponder()
    if r == true {
      onSelectionChange(editor: editor)
    }
    return r
  }

  internal func validateNativeSelection(_ textView: UITextView) {
    guard let selectedRange = textView.selectedTextRange else { return }

    let start = validatePosition(textView: textView, position: selectedRange.start, direction: .forward)
    let end = validatePosition(textView: textView, position: selectedRange.end, direction: .forward)

    if start != selectedRange.start || end != selectedRange.end {
      isUpdatingNativeSelection = true
      selectedTextRange = textRange(from: start, to: end)
      isUpdatingNativeSelection = false
    }
  }
}

private class TextViewDelegate: NSObject, UITextViewDelegate {
  private var editor: Editor

  init(editor: Editor) {
    self.editor = editor
  }

  public func textViewDidChangeSelection(_ textView: UITextView) {
    guard let textView = textView as? TextView else { return }

    if textView.isUpdatingNativeSelection {
      return
    }

    if let interception = textView.interceptNextSelectionChangeAndReplaceWithRange {
      textView.interceptNextSelectionChangeAndReplaceWithRange = nil
      textView.selectedRange = interception
      return
    }

    textView.validateNativeSelection(textView)
    onSelectionChange(editor: textView.editor)
  }

  public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    guard let textView = textView as? TextView else { return false }

    textView.hidePlaceholderLabel()
    if let lexicalDelegate = textView.lexicalDelegate {
      return lexicalDelegate.textViewShouldChangeText(textView, range: range, replacementText: text)
    }

    return true
  }

  public func textViewDidBeginEditing(_ textView: UITextView) {
    guard let textView = textView as? TextView else { return }

    editor.dispatchCommand(type: .beginEditing)
    textView.lexicalDelegate?.textViewDidBeginEditing(textView: textView)
  }

  public func textViewDidEndEditing(_ textView: UITextView) {
    guard let textView = textView as? TextView else { return }

    editor.dispatchCommand(type: .endEditing)
    textView.lexicalDelegate?.textViewDidEndEditing(textView: textView)
  }

  public func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
    guard let textView = textView as? TextView else { return false }

      // TODO: consider updating `.linkTapped` payload to include this native selection if we want that behavior.
//    let nativeSelection = NativeSelection(range: characterRange, affinity: .backward)
//    try? textView.editor.update {
//      guard let selection = try getSelection() as? RangeSelection else {
//        // TODO: cope with non range selections. Should just make a range selection here
//        return
//      }
//      try selection.applyNativeSelection(nativeSelection)
//    }
      
    let handledByLexical = textView.editor.dispatchCommand(type: .linkTapped, payload: URL)

    if handledByLexical {
      return false
    }

    if !textView.isEditable {
      return true
    }

    return textView.lexicalDelegate?.textView(textView, shouldInteractWith: URL, in: characterRange, interaction: interaction) ?? false
  }
}

//  The problem we're trying to solve:
//    If we set a paragraphStyle attribute with a paragraphSpacing value to add some space after a heading for an example
//    the caret, when in the last line of such a paragraph, will have an abonormally large height and will be effectively
//    longer for the space added. This also happens if we apply setBlockLevelAttributes padding or margin since it also
//    uses paragraphStyle.paragraphSpacing under the hood. Also selection carets, or handles, will be affected.
//
//  If, at some point, we want to use paragraphStyle.beforeParagraphSpacing, to add some space on the top of the paragraph
//  we will have to adjust this adjuster. Since we don't have such plans atm I opted to skip it to save time and effort
//  and also not complicate this code unnecessarily.
private class CaretAndSelectionRectsAdjuster {

  static func adjustCaretRect(_ originalRect: CGRect, for position: UITextPosition, in textView: UITextView) -> CGRect {
    var result = originalRect
    if isCaretOnLastLine(for: position, in: textView) {
      // Find the caret position as an index in the text
      let offset = textView.offset(from: textView.beginningOfDocument, to: position)
      // Retrieve attributes at the caret position
      let attributes = textView.textStorage.attributes(at: offset, effectiveRange: nil)
      if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
        result.size.height = result.size.height - paragraphStyle.paragraphSpacing
      }
    }

    return result
  }

  static func adjustSelectionRects(_ originalRects: [UITextSelectionRect], for range: UITextRange, in textView: UITextView) -> [UITextSelectionRect] {
    // Create a modified array of selection rects with adjusted heights
    let modifiedRects = originalRects.map { originalRect -> UITextSelectionRect in
      let rect = originalRect.rect
      if originalRect.containsStart {
        let adjustedRect = adjustCaretRect(rect, for: range.start, in: textView)
        return CustomSelectionRect(baseRect: originalRect, adjustedRect: adjustedRect)
      }
      if originalRect.containsEnd {
        let adjustedRect = adjustCaretRect(rect, for: range.end, in: textView)
        return CustomSelectionRect(baseRect: originalRect, adjustedRect: adjustedRect)
      }
      // no change
      return CustomSelectionRect(baseRect: originalRect, adjustedRect: originalRect.rect)
    }

    return modifiedRects
  }

  static func isCaretOnLastLine(for position: UITextPosition, in textView: UITextView) -> Bool {
    let caretOffset = textView.offset(from: textView.beginningOfDocument, to: position)

    // Get the paragraph range containing the caret
    let nsText = textView.textStorage.string as NSString
    let paragraphRange = nsText.paragraphRange(for: NSRange(location: caretOffset, length: 0))

    // Check line fragment of the caret
    let glyphIndex = textView.layoutManager.glyphIndexForCharacter(at: caretOffset)
    let lineFragmentRect = textView.layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

    // Determine the last line of the paragraph
    let paragraphEndGlyphIndex = textView.layoutManager.glyphIndexForCharacter(at: paragraphRange.upperBound - 1)
    let lastLineFragmentRect = textView.layoutManager.lineFragmentRect(forGlyphAt: paragraphEndGlyphIndex, effectiveRange: nil)

    // Compare the current caret's line to the last line of the paragraph
    return lineFragmentRect == lastLineFragmentRect
  }

}

// Custom UITextSelectionRect subclass for modified rects
private class CustomSelectionRect: UITextSelectionRect {
    private let baseRect: UITextSelectionRect
    private let customRect: CGRect

    init(baseRect: UITextSelectionRect, adjustedRect: CGRect) {
        self.baseRect = baseRect
        self.customRect = adjustedRect
        super.init()
    }

    override var rect: CGRect {
        return customRect
    }

    override var containsStart: Bool {
        return baseRect.containsStart
    }

    override var containsEnd: Bool {
        return baseRect.containsEnd
    }

    override var isVertical: Bool {
        return baseRect.isVertical
    }
}
