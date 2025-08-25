/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import XCTest

@testable import Lexical
@testable import LexicalListPlugin
@testable import LexicalMarkdown

class LexicalMarkdownTests: XCTestCase {
  var lexicalView: LexicalView?
  var editor: Editor? {
    get {
      return lexicalView?.editor
    }
  }

  override func setUp() {
    lexicalView = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
  }

  override func tearDown() {
    lexicalView = nil
  }

  func testListWithInlineStyles() throws {
    guard let editor = self.editor else {
      XCTFail("no editor")
      return
    }
    try editor.update {
      guard let rootNode = getRoot()
      else {
        XCTFail("should have root node")
        return
      }

      try rootNode.getChildren().forEach { node in
        try node.remove()
      }

      // Root level
      let list = ListNode(listType: .bullet, start: 1)

      let item1 = ListItemNode()
      try item1.append([TextNode(text: "Item 1")])

      let item2 = ListItemNode()
      let boldText = TextNode(text: "2")
      try boldText.setBold(true)
      try item2.append([TextNode(text: "Item "), boldText])

      try list.append([item1, item2])
      try rootNode.append([list])
    }

    let markdownString = try LexicalMarkdown.generateMarkdown(from: editor, selection: nil)
    let comparison = """
      - Item 1
      - Item **2**
      """
    XCTAssertEqual(markdownString, comparison)
  }
}
