/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

@objc public protocol Plugin {
  func setUp(editor: Editor)
  func tearDown()
    @objc optional func hitTest(at point: CGPoint, lineFragmentRect: CGRect, firstCharacterRect: CGRect, attributes: [NSAttributedString.Key : Any]) -> Bool
    @objc optional func handleTap(at point: CGPoint, lineFragmentRect: CGRect, firstCharacterRect: CGRect, attributes: [NSAttributedString.Key : Any]) -> Bool
}

extension Plugin {
  public static func installedInstance() throws -> Self? {
    guard let editor = getActiveEditor() else {
      throw LexicalError.invariantViolation("Expected editor")
    }
    for plugin in editor.plugins {
      if let plugin = plugin as? Self {
        return plugin
      }
    }
    return nil
  }
}
