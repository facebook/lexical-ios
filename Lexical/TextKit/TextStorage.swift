// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import UIKit

public class TextStorage: NSTextStorage {

  private var backingAttributedString: NSMutableAttributedString
  var mode: TextStorageEditingMode
  weak var editor: Editor?

  override public init() {
    backingAttributedString = NSMutableAttributedString()
    mode = TextStorageEditingMode.none
    super.init()
  }

  convenience init(editor: Editor) {
    self.init()
    self.editor = editor
    self.backingAttributedString = NSMutableAttributedString()
    self.mode = TextStorageEditingMode.none
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("\(#function) has not been implemented")
  }

  override open var string: String {
    return backingAttributedString.string
  }

  override open func attributes(
    at location: Int,
    effectiveRange range: NSRangePointer?
  ) -> [NSAttributedString.Key: Any] {
    if backingAttributedString.length <= location {
      editor?.log(.NSTextStorage, .error, "Index out of range")
      return [:]
    }
    return backingAttributedString.attributes(at: location, effectiveRange: range)
  }

  override open func replaceCharacters(in range: NSRange, with attrString: NSAttributedString) {
    if mode == .none {
      // If mode is none (i.e. an update that hasn't gone through either controller or non-controlled mode yet),
      // we discard attribute information here. This applies to e.g. autocomplete, but it lets us handle it
      // using Lexical's own attribute persistence logic rather than UIKit's. The reason for doing it this way
      // is to avoid UIKit stomping on our custom attributes.
      editor?.log(.NSTextStorage, .verboseIncludingUserContent, "Replace characters mode=none, string length \(self.backingAttributedString.length), range \(range), replacement \(attrString.string)")
      performControllerModeUpdate(attrString.string, range: range)
      return
    }
    // Since we're in either controller or non-controlled mode, call super -- this will in turn call
    // both replaceCharacters and replaceAttributes.
    super.replaceCharacters(in: range, with: attrString)
  }

  override open func replaceCharacters(in range: NSRange, with str: String) {
    if mode == .none {
      performControllerModeUpdate(str, range: range)
      return
    }

    // Mode is not none, so this change has already passed through Lexical
    beginEditing()
    backingAttributedString.replaceCharacters(in: range, with: str)
    edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
    endEditing()
  }

  private func performControllerModeUpdate(_ str: String, range: NSRange) {
    mode = .controllerMode
    defer {
      mode = .none
    }

    do {
      guard let editor = editor, let frontend = editor.frontend else { return }

      let nativeSelection = NativeSelection(range: range, affinity: .forward)
      var updatedSelection: RangeSelection?
      try editor.update {
        guard let selection = getSelection() else {
          return // expected lexical selection
        }
        try selection.applyNativeSelection(nativeSelection)
        try selection.insertText(str)
        updatedSelection = getSelection()
      }
      guard let updatedSelection = updatedSelection else {
        return
      }
      try editor.getEditorState().read {
        let updatedNativeSelection = try createNativeSelection(from: updatedSelection, editor: editor)
        frontend.interceptNextSelectionChangeAndReplaceWithRange = updatedNativeSelection.range
      }

      frontend.showPlaceholderText()
    } catch {
      print("\(error)")
    }
    return
  }

  override open func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
    if mode != .controllerMode {
      return
    }

    beginEditing()
    backingAttributedString.setAttributes(attrs, range: range)
    edited(.editedAttributes, range: range, changeInLength: 0)
    endEditing()
  }
}
