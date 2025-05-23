/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical
import Markdown

open class LexicalMarkdown: Plugin {
  public init() {}

  weak var editor: Editor?

  public func setUp(editor: Editor) {
    self.editor = editor
  }

  public func tearDown() {
  }

  public class func generateMarkdown(
    from editor: Editor,
    selection: BaseSelection?
  ) throws -> String {
    var markdownString = ""
    try editor.read {
      guard let root = getRoot() else {
        throw LexicalError.invariantViolation("Expected root node")
      }
      markdownString = Markdown.Document(root.getChildren().exportAsBlockMarkdown()).format()
    }
    return markdownString
  }
}
