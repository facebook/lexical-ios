/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
@testable import Lexical
@testable import LexicalHTML
import XCTest

class LexicalHTMLTests: XCTestCase {

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

  func testNodesToHTML() throws {
    guard let editor else { XCTFail(); return }

    let comparison = """
<p>
 <span>
  hello world
 </span>
</p>
"""

    try editor.update {
      let textNode = TextNode()
      try textNode.setText("hello world")

      guard let root = getRoot(), let paragraphNode = root.getFirstChild() as? ParagraphNode else {
        XCTFail()
        return
      }
      try paragraphNode.append([textNode])

      let html = try generateHTMLFromNodes(editor: editor, selection: nil)
      XCTAssertEqual(html, comparison, "Incorrect HTML")
    }
  }
}
