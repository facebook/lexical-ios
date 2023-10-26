/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

@available(*, deprecated, message: "Please use the new Styles system (see Styles.swift)")
public func updateTextFormat(type: TextFormatType, editor: Editor) throws {
  guard getActiveEditor() != nil else {
    throw LexicalError.invariantViolation("Must have editor")
  }
  guard let selection = try getSelection() as? RangeSelection else {
    return
  }

  try selection.formatText(formatType: type)
}
