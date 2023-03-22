// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation

@objc public protocol Plugin {
  func setUp(editor: Editor)
  func tearDown()
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
