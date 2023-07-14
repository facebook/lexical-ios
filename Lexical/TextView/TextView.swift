/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import MobileCoreServices
import UIKit

protocol LexicalTextViewDelegate: NSObjectProtocol {
  func textViewDidBeginEditing(textView: TextView)
  func textViewDidEndEditing(textView: TextView)
  func textViewShouldChangeText(_ textView: UITextView, range: NSRange, replacementText text: String) -> Bool
  func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool
}

class TextView: UITextView {
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

    super.init(frame: .zero, textContainer: textContainer)

    if useInputDelegateProxy {
      inputDelegateProxy.targetInputDelegate = self.inputDelegate
      super.inputDelegate = inputDelegateProxy
    }

    delegate = self
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

  override func layoutSubviews() {
    super.layoutSubviews()

    placeholderLabel.frame.origin = CGPoint(x: textContainer.lineFragmentPadding * 1.5 + textContainerInset.left, y: textContainerInset.top)
    placeholderLabel.sizeToFit()
  }

  override var inputDelegate: UITextInputDelegate? {
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

  // MARK: - Incoming events

  override func deleteBackward() {
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
  }

  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(paste(_:)) {
      if pasteboard.hasStrings {
        return true
      } else if !(pasteboard.data(forPasteboardType: LexicalConstants.pasteboardIdentifier)?.isEmpty ?? true) {
        return true
      } else if !(pasteboard.data(forPasteboardType: (kUTTypeUTF8PlainText as String))?.isEmpty ?? true) {
        return true
      } else {
        return super.canPerformAction(action, withSender: sender)
      }
    } else {
      return super.canPerformAction(action, withSender: sender)
    }
  }

  override func copy(_ sender: Any?) {
    editor.dispatchCommand(type: .copy, payload: pasteboard)
  }

  override func cut(_ sender: Any?) {
    editor.dispatchCommand(type: .cut, payload: pasteboard)
  }

  override func paste(_ sender: Any?) {
    editor.dispatchCommand(type: .paste, payload: pasteboard)
  }

  override func insertText(_ text: String) {
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

  override func setAttributedMarkedText(_ markedText: NSAttributedString?, selectedRange: NSRange) {
    editor.log(.UITextView, .verbose)
    if let markedText {
      setMarkedTextInternal(markedText.string, selectedRange: selectedRange)
    } else {
      unmarkText()
    }
  }

  override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
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

  override func unmarkText() {
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

  func setPlaceholderText(_ text: String, textColor: UIColor, font: UIFont) {
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

  private func hidePlaceholderLabel() {
    placeholderLabel.isHidden = true
  }

  override func becomeFirstResponder() -> Bool {
    let r = super.becomeFirstResponder()
    if r == true {
      onSelectionChange(editor: editor)
    }
    return r
  }
}

extension TextView: UITextViewDelegate {
  public func textViewDidChangeSelection(_ textView: UITextView) {

    if isUpdatingNativeSelection {
      return
    }

    if let interception = interceptNextSelectionChangeAndReplaceWithRange {
      interceptNextSelectionChangeAndReplaceWithRange = nil
      selectedRange = interception
      return
    }

    onSelectionChange(editor: editor)
  }

  public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    hidePlaceholderLabel()
    if let lexicalDelegate = lexicalDelegate {
      return lexicalDelegate.textViewShouldChangeText(self, range: range, replacementText: text)
    }

    return true
  }

  public func textViewDidBeginEditing(_ textView: UITextView) {
    lexicalDelegate?.textViewDidBeginEditing(textView: self)
  }

  public func textViewDidEndEditing(_ textView: UITextView) {
    lexicalDelegate?.textViewDidEndEditing(textView: self)
  }

  public func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {

    let nativeSelection = NativeSelection(range: characterRange, affinity: .backward)
    try? editor.update {
      guard let selection = try getSelection() as? RangeSelection else {
        // TODO: cope with non range selections. Should just make a range selection here
        return
      }
      try selection.applyNativeSelection(nativeSelection)
    }
    let handledByLexical = self.editor.dispatchCommand(type: .linkTapped, payload: URL)

    if handledByLexical {
      return false
    }

    if !isEditable {
      return true
    }

    return lexicalDelegate?.textView(self, shouldInteractWith: URL, in: characterRange, interaction: interaction) ?? false
  }
}
