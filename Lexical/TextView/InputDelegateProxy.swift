// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import UIKit

internal class InputDelegateProxy: NSObject, UITextInputDelegate {
  internal weak var targetInputDelegate: UITextInputDelegate?
  internal var isSuspended: Bool = false

  func selectionWillChange(_ textInput: UITextInput?) {
    if let targetInputDelegate = targetInputDelegate, isSuspended == false {
      targetInputDelegate.selectionWillChange(textInput)
    }
  }

  func selectionDidChange(_ textInput: UITextInput?) {
    if let targetInputDelegate = targetInputDelegate, isSuspended == false {
      targetInputDelegate.selectionDidChange(textInput)
    }
  }

  func textWillChange(_ textInput: UITextInput?) {
    if let targetInputDelegate = targetInputDelegate, isSuspended == false {
      targetInputDelegate.textWillChange(textInput)
    }
  }

  func textDidChange(_ textInput: UITextInput?) {
    if let targetInputDelegate = targetInputDelegate, isSuspended == false {
      targetInputDelegate.textDidChange(textInput)
    }
  }

  // Note that this function only sends a didChange.
  internal func sendSelectionChangedIgnoringSuspended(_ textInput: UITextInput?) {
    if let targetInputDelegate = targetInputDelegate {
      targetInputDelegate.selectionDidChange(textInput)
    }
  }
}
