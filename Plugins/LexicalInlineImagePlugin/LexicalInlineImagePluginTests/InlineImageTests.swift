/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

@testable import Lexical
@testable import LexicalInlineImagePlugin

class InlineImageTests: XCTestCase {
  var view: LexicalView?
  var editor: Editor {
    get {
      guard let editor = view?.editor else {
        XCTFail("Editor unexpectedly nil")
        fatalError()
      }
      return editor
    }
  }

  override func setUp() {
    view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: [InlineImagePlugin()]), featureFlags: FeatureFlags())
  }

  override func tearDown() {
    view = nil
  }

  func testNewParaAfterImage() throws {
    try editor.update {
      let imageNode = ImageNode(url: "https://example.com/image.png", size: CGSize(width: 300, height: 300), sourceID: "")
      let textNode1 = TextNode(text: "123")
      let textNode2 = TextNode(text: "456")
      if let selection = try getSelection() {
        _ = try selection.insertNodes(nodes: [textNode1, imageNode, textNode2], selectStart: false)
      }

      guard let root = getRoot() else {
        XCTFail()
        return
      }
      XCTAssertEqual(root.getChildrenSize(), 1, "Root should have 1 child (paragraph)")

      let newSelection = RangeSelection(anchor: Point(key: textNode2.getKey(), offset: 0, type: .text), focus: Point(key: textNode2.getKey(), offset: 0, type: .text), format: TextFormat())
      try newSelection.insertParagraph()

      XCTAssertEqual(root.getChildrenSize(), 2, "Root should now have 2 paragraphs")

      let firstPara = root.getChildren()[0] as? ParagraphNode
      let secondPara = root.getChildren()[1] as? ParagraphNode

      guard let firstPara, let secondPara else {
        XCTFail()
        return
      }

      XCTAssertEqual(firstPara.getChildrenSize(), 2, "First para should contain 1 text node and 1 image node")
      XCTAssertEqual(secondPara.getChildrenSize(), 1, "Second para should contain 1 text node")
    }
  }
}
