/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

@testable import Lexical
@testable import LexicalListPlugin

class ListItemNodeTests: XCTestCase {
  var view: LexicalView?

  var editor: Editor? {
    return view?.editor
  }

  override func setUp() {
    view = LexicalView(
      editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
  }

  override func tearDown() {
    view = nil
  }

  func debugEditor(_ editor: Editor) {
    print((try? getNodeHierarchy(editorState: editor.getEditorState())) ?? "")
    print(view?.textStorage.debugDescription ?? "")
    print((try? getSelectionData(editorState: editor.getEditorState())) ?? "")
    print((try? editor.getEditorState().toJSON(outputFormatting: .sortedKeys)) ?? "")
  }

  func testItemCharacterWithNestedNumberedList() throws {
    guard let editor else {
      XCTFail("Editor unexpectedly nil")
      return
    }

    try editor.update {
      guard
        let editorState = getActiveEditorState(),
        let rootNode = editorState.getRootNode()
      else {
        XCTFail("should have editor state")
        return
      }

      /*
       1. Item 1
       1. Nested item 1
       2. Nested item 2
       2. Item 2
       */

      // Root level
      let list = ListNode(listType: .number, start: 1)

      let item1 = ListItemNode()
      try item1.append([TextNode(text: "Item 1")])

      let item2 = ListItemNode()
      try item2.append([TextNode(text: "Item 2")])

      // Nested level
      let nestedList = ListNode(listType: .number, start: 1)

      let nestedListItem = ListItemNode()
      try nestedListItem.append([nestedList])

      let nestedItem1 = ListItemNode()
      try nestedItem1.append([TextNode(text: "Nested item 1")])

      let nestedItem2 = ListItemNode()
      try nestedItem2.append([TextNode(text: "Nested item 2")])

      try nestedList.append([nestedItem1, nestedItem2])

      // Putting it together
      try list.append([item1, nestedListItem, item2])
      try rootNode.append([list])

      // Assertions
      let theme = editor.getTheme()

      let item1Attrs =
        item1.getAttributedStringAttributes(theme: theme)[.listItem] as? ListItemAttribute
      XCTAssertEqual(item1Attrs?.listItemCharacter, "1.")

      let item2Attrs =
        item2.getAttributedStringAttributes(theme: theme)[.listItem] as? ListItemAttribute
      XCTAssertEqual(item2Attrs?.listItemCharacter, "2.")

      let nestedItem1Attrs =
        nestedItem1.getAttributedStringAttributes(theme: theme)[.listItem] as? ListItemAttribute
      XCTAssertEqual(nestedItem1Attrs?.listItemCharacter, "1.")

      let nestedItem2Attrs =
        nestedItem2.getAttributedStringAttributes(theme: theme)[.listItem] as? ListItemAttribute
      XCTAssertEqual(nestedItem2Attrs?.listItemCharacter, "2.")
    }
  }

  func testRemoveEmptyListItemNodes() throws {
    guard let editor else {
      XCTFail("Editor unexpectedly nil")
      return
    }

    try editor.update {
      guard
        let editorState = getActiveEditorState(),
        let rootNode = editorState.getRootNode(),
        let firstNode = rootNode.getChildren().first
      else {
        XCTFail("should have editor state")
        return
      }

      let list = ListNode(listType: .bullet, start: 1)

      let item1 = ListItemNode()
      let item2 = ListItemNode()

      try list.append([item1, item2])
      try firstNode.replace(replaceWith: list)

      // select the last list item node
      try item2.select(anchorOffset: nil, focusOffset: nil)
    }

    // from the last list item node, simulate pressing backspace
    try editor.update {
      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("should have selection")
        return
      }

      debugEditor(editor)

      try selection.deleteCharacter(isBackwards: true)
    }

    // verify we only have one list item left
    try editor.read {
      debugEditor(editor)

      guard let root = getRoot() else {
        XCTFail("should have root")
        return
      }

      XCTAssertEqual(root.getChildren().count, 1)
      guard let list = root.getChildren().first as? ListNode else {
        XCTFail("should have list")
        return
      }

      XCTAssertEqual(list.getChildren().count, 1)
      guard let item1 = list.getChildren().first as? ListItemNode else {
        XCTFail("should have item1")
        return
      }

      XCTAssertEqual(item1.getChildren().count, 0)

      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("should have selection")
        return
      }

      XCTAssert(selection.anchor.type == .element)
      XCTAssert(selection.anchor.key == item1.key)
    }

    // simulate another backspace
    try editor.update {
      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("should have selection")
        return
      }

      debugEditor(editor)

      try selection.deleteCharacter(isBackwards: true)
    }

    // verify we collapse the list into a paragraph
    try editor.read {
      guard let root = getRoot() else {
        XCTFail("should have root")
        return
      }

      XCTAssertEqual(root.getChildren().count, 1)
      guard let firstNode = root.getChildren().first else {
        XCTFail("should have first node")
        return
      }

      debugEditor(editor)

      XCTAssertEqual(firstNode.type, .paragraph)
    }
  }

  func testCollapseListItemNodesWithContent() throws {
    guard let editor else {
      XCTFail("Editor unexpectedly nil")
      return
    }

    try editor.update {
      guard
        let editorState = getActiveEditorState(),
        let rootNode = editorState.getRootNode(),
        let firstNode = rootNode.getChildren().first
      else {
        XCTFail("should have editor state")
        return
      }

      let list = ListNode(listType: .bullet, start: 1)

      let item1 = ListItemNode()
      let textNode1 = TextNode(text: "1")
      try item1.append([textNode1])

      let item2 = ListItemNode()
      let textNode2 = TextNode(text: "2")
      try item2.append([textNode2])

      try list.append([item1, item2])
      try firstNode.replace(replaceWith: list)

      // select the last list item node
      // select the start of the last line
      try textNode2.select(anchorOffset: 0, focusOffset: 0)
    }

    // from the last list item node, simulate pressing backspace
    try editor.update {
      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("should have selection")
        return
      }

      debugEditor(editor)

      try selection.deleteCharacter(isBackwards: true)
    }

    // verify we only have one list item left
    try editor.read {
      debugEditor(editor)

      guard let root = getRoot() else {
        XCTFail("should have root")
        return
      }

      XCTAssertEqual(root.getChildren().count, 1)
      guard let list = root.getChildren().first as? ListNode else {
        XCTFail("should have list")
        return
      }

      XCTAssertEqual(list.getChildren().count, 1)
      guard let item1 = list.getChildren().first as? ListItemNode else {
        XCTFail("should have item1")
        return
      }

      XCTAssertEqual(item1.getChildren().count, 1)
      guard let textNode1 = item1.getChildren().first as? TextNode else {
        XCTFail("should have textNode1")
        return
      }

      XCTAssertEqual(textNode1.getTextPart(), "12")
    }
  }

  func testRemoveListItemNodesWithContent() throws {
    guard let editor else {
      XCTFail("Editor unexpectedly nil")
      return
    }

    try editor.update {
      guard
        let editorState = getActiveEditorState(),
        let rootNode = editorState.getRootNode(),
        let firstNode = rootNode.getChildren().first
      else {
        XCTFail("should have editor state")
        return
      }

      let list = ListNode(listType: .bullet, start: 1)

      let item1 = ListItemNode()
      let textNode1 = TextNode(text: "1")
      try item1.append([textNode1])

      let item2 = ListItemNode()
      let textNode2 = TextNode(text: "2")
      try item2.append([textNode2])

      try list.append([item1, item2])
      try firstNode.replace(replaceWith: list)

      // select the last list item node
      // select the start of the last line
      try textNode2.select(anchorOffset: nil, focusOffset: nil)
    }

    // from the last list item node, simulate pressing backspace
    try editor.update {
      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("should have selection")
        return
      }

      debugEditor(editor)

      try selection.deleteCharacter(isBackwards: true)
    }

    try editor.update {
      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("should have selection")
        return
      }

      guard let root = getRoot() else {
        XCTFail("should have root")
        return
      }

      XCTAssertEqual(root.getChildren().count, 1)
      guard let list = root.getChildren().first as? ListNode else {
        XCTFail("should have list")
        return
      }

      XCTAssertEqual(list.getChildren().count, 2)
      guard let item1 = list.getChildren().first as? ListItemNode,
        let item2 = list.getChildren().last as? ListItemNode
      else {
        XCTFail("should have items")
        return
      }

      XCTAssertEqual(item1.getChildren().count, 1)
      XCTAssertEqual(item2.getChildren().count, 0)

      try selection.deleteCharacter(isBackwards: true)
    }

    // verify we only have one list item left
    try editor.read {
      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("should have selection")
        return
      }

      guard let root = getRoot() else {
        XCTFail("should have root")
        return
      }

      XCTAssertEqual(root.getChildren().count, 1)
      guard let list = root.getChildren().first as? ListNode else {
        XCTFail("should have list")
        return
      }

      XCTAssertEqual(list.getChildren().count, 1)
      guard let item1 = list.getChildren().first as? ListItemNode else {
        XCTFail("should have items")
        return
      }

      XCTAssertEqual(item1.getChildren().count, 1)
    }
  }

  func testEditEmptyListItemNodesInMiddleOfList() throws {
    guard let editor else {
      XCTFail("Editor unexpectedly nil")
      return
    }

    try editor.update {
      guard
        let editorState = getActiveEditorState(),
        let rootNode = editorState.getRootNode(),
        let firstNode = rootNode.getChildren().first
      else {
        XCTFail("should have editor state")
        return
      }

      let list = ListNode(listType: .bullet, start: 1)

      let item1 = ListItemNode()
      let textNode1 = TextNode(text: "1")
      try item1.append([textNode1])

      let item2 = ListItemNode()
      let item3 = ListItemNode()
      let item4 = ListItemNode()
      let textNode4 = TextNode(text: "4")
      try item4.append([textNode4])

      try list.append([item1, item2, item3, item4])
      try firstNode.replace(replaceWith: list)

      try textNode4.select(anchorOffset: nil, focusOffset: nil)
    }

    view?.textView.selectedRange = NSRange(location: 6, length: 0)

    try editor.update {
      guard let textView = view?.textView as? UITextView else {
        XCTFail("should have textView")
        return
      }

      debugEditor(editor)

      view?.textView.validateNativeSelection(textView)
      onSelectionChange(editor: editor)

      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("should have selection")
        return
      }

      try selection.insertText("3")

    }

    try editor.read {
      debugEditor(editor)

      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("should have selection")
        return
      }

      XCTAssertEqual(try selection.anchor.getNode().getTextPart(), "3")

      guard
        let list = try selection.anchor.getNode().getParentOrThrow().getParentOrThrow() as? ListNode
      else {
        XCTFail("should have list")
        return
      }

      guard let listItem3 = list.getChildAtIndex(index: 2) as? ListItemNode else {
        XCTFail("should have listItem4")
        return
      }

      XCTAssertEqual(
        listItem3.getTextContent().trimmingCharacters(in: .whitespacesAndNewlines), "3")

      guard let listItem4 = list.getChildAtIndex(index: 3) as? ListItemNode else {
        XCTFail("should have listItem4")
        return
      }

      XCTAssertEqual(
        listItem4.getTextContent().trimmingCharacters(in: .whitespacesAndNewlines), "4")
    }
  }

  func testDeleteMultipleEmptyListItemNodes() throws {
    guard let editor else {
      XCTFail("Editor unexpectedly nil")
      return
    }

    try editor.update {
      guard
        let editorState = getActiveEditorState(),
        let rootNode = editorState.getRootNode(),
        let firstNode = rootNode.getChildren().first
      else {
        XCTFail("should have editor state")
        return
      }

      let list = ListNode(listType: .bullet, start: 1)

      let item1 = ListItemNode()
      let item2 = ListItemNode()
      let item3 = ListItemNode()
      let item4 = ListItemNode()

      try list.append([item1, item2, item3, item4])
      try firstNode.replace(replaceWith: list)

      try item4.select(anchorOffset: nil, focusOffset: nil)
    }

    // from the last list item node, simulate pressing backspace
    try editor.update {
      guard let textView = view?.textView as? UITextView else {
        XCTFail("should have textView")
        return
      }

      debugEditor(editor)

      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("should have selection")
        return
      }

      try selection.deleteCharacter(isBackwards: true)
    }

    // from the last list item node, simulate pressing backspace
    try editor.update {
      guard let textView = view?.textView as? UITextView else {
        XCTFail("should have textView")
        return
      }

      debugEditor(editor)

      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("should have selection")
        return
      }

      try selection.deleteCharacter(isBackwards: true)
    }

    // from the last list item node, simulate pressing backspace
    try editor.update {
      guard let textView = view?.textView as? UITextView else {
        XCTFail("should have textView")
        return
      }

      debugEditor(editor)

      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("should have selection")
        return
      }

      try selection.deleteCharacter(isBackwards: true)
    }
  }

}
