/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

@testable import Lexical
@testable import LexicalListPlugin
import XCTest

class ListItemNodeTests: XCTestCase {
  var view: LexicalView?

  var editor: Editor? {
    get {
      return view?.editor
    }
  }

  override func setUp() {
    view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
  }

  override func tearDown() {
    view = nil
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

      let item1Attrs = item1.getAttributedStringAttributes(theme: theme)[.listItem] as? ListItemAttribute
      XCTAssertEqual(item1Attrs?.listItemCharacter, "1.")

      let item2Attrs = item2.getAttributedStringAttributes(theme: theme)[.listItem] as? ListItemAttribute
      XCTAssertEqual(item2Attrs?.listItemCharacter, "2.")

      let nestedItem1Attrs = nestedItem1.getAttributedStringAttributes(theme: theme)[.listItem] as? ListItemAttribute
      XCTAssertEqual(nestedItem1Attrs?.listItemCharacter, "1.")

      let nestedItem2Attrs = nestedItem2.getAttributedStringAttributes(theme: theme)[.listItem] as? ListItemAttribute
      XCTAssertEqual(nestedItem2Attrs?.listItemCharacter, "2.")
    }
  }

  func testInsertListWithPlaceholders() throws {
    guard let editor else {
      XCTFail("Editor unexpectedly nil")
      return
    }

    try editor.update {
      guard let rootNode = getActiveEditorState()?.getRootNode() else {
        XCTFail("Root node not found")
        return
      }

      try insertList(editor: editor, listType: .bullet, withPlaceholders: true)
      print("root node: \(rootNode.getChildren())")

      XCTAssertEqual(rootNode.getChildrenSize(), 1)
      guard let listNode = rootNode.getFirstChild() as? ListNode else {
        XCTFail("List node not created")
        return
      }
      XCTAssertEqual(listNode.getChildrenSize(), 1)
      guard let listItemNode = listNode.getFirstChild() as? ListItemNode else {
        XCTFail("List item node not created")
        return
      }
      XCTAssertEqual(listItemNode.getChildrenSize(), 1)
      XCTAssertTrue(listItemNode.getFirstChild() is ListItemPlaceholderNode)

      // Simulate hitting enter on the empty list item
      var result = try listItemNode.insertNewAfter(selection: nil)
      guard let newNode = result.element as? ListItemNode else {
        XCTFail("Failed to insert new list item")
        return
      }

      // Verify that a new list item was created
      XCTAssertEqual(listNode.getChildrenSize(), 2, "A new list item should be created")

      // Verify that the original list item still exists
      XCTAssertTrue(listNode.getChildren().contains(where: { $0.key == listItemNode.key }),
                    "The original list item should still exist")

      print("children: \(newNode) \(newNode.getChildren())")

      // Verify that the new list item has a placeholder
      XCTAssertEqual(newNode.getChildrenSize(), 1, "New list item should have one child")
      XCTAssertTrue(newNode.getFirstChild() is ListItemPlaceholderNode,
                    "New list item should contain a placeholder")

      // Verify that the original list item still has its placeholder
      XCTAssertEqual(listItemNode.getChildrenSize(), 1, "Original list item should still have one child")
      XCTAssertTrue(listItemNode.getFirstChild() is ListItemPlaceholderNode,
                    "Original list item should still contain a placeholder")
      XCTAssertTrue(listItemNode.getFirstChild()?.type == .listItemPlaceholder, "Placeholder should be listItemPlaceholder type")

      // Add text to the first list item
      try listItemNode.select(anchorOffset: nil, focusOffset: nil)
      editor.dispatchCommand(type: .insertText, payload: "Hello, world!")

      // Verify that the text was added
      XCTAssertEqual(listItemNode.getChildrenSize(), 1, "List item should have one child after adding text")
      XCTAssertTrue(listItemNode.getFirstChild() is TextNode, "List item should contain a text node")
      XCTAssertEqual((listItemNode.getFirstChild() as? TextNode)?.getTextContent(), "Hello, world!", "Text content should match")

      // Simulate hitting enter after the text
      result = try listItemNode.insertNewAfter(selection: nil)
      guard let newNodeAfterText = result.element as? ListItemNode else {
        XCTFail("Failed to insert new list item after text")
        return
      }

      // Verify that a new list item was created
      XCTAssertEqual(listNode.getChildrenSize(), 3, "A new list item should be created after text")

      // Verify that the original list item still contains the text
      XCTAssertEqual(listItemNode.getChildrenSize(), 1, "Original list item should still have one child")
      XCTAssertTrue(listItemNode.getFirstChild() is TextNode, "Original list item should still contain the text node")
      XCTAssertEqual((listItemNode.getFirstChild() as? TextNode)?.getTextContent(), "Hello, world!", "Text content should remain unchanged")

      // Verify that the new list item has a placeholder
      XCTAssertEqual(newNodeAfterText.getChildrenSize(), 1, "New list item after text should have one child")
      XCTAssertTrue(newNodeAfterText.getFirstChild() is ListItemPlaceholderNode,
                    "New list item after text should contain a placeholder")
    }
  }

  func testAppendToListItemWithPlaceholder() throws {
    guard let editor else {
      XCTFail("Editor unexpectedly nil")
      return
    }

    try editor.update {
      guard let rootNode = getActiveEditorState()?.getRootNode() else {
        XCTFail("Root node not found")
        return
      }

      try insertList(editor: editor, listType: .bullet, withPlaceholders: true)

      guard let listNode = rootNode.getFirstChild() as? ListNode,
            let listItemNode = listNode.getFirstChild() as? ListItemNode else {
        XCTFail("List structure not created correctly")
        return
      }

      try listItemNode.append([TextNode(text: "New content")])

      XCTAssertFalse(listItemNode.getFirstChild() is ListItemPlaceholderNode)
      XCTAssertEqual(listItemNode.getTextContent(), "New content")
    }
  }

  func testRemoveEmptyListItemWithPlaceholder() throws {
    guard let editor else {
      XCTFail("Editor unexpectedly nil")
      return
    }

    try editor.update {
      guard let rootNode = getActiveEditorState()?.getRootNode() else {
        XCTFail("Root node not found")
        return
      }

      try insertList(editor: editor, listType: .bullet, withPlaceholders: true)

      guard let listNode = rootNode.getFirstChild() as? ListNode,
            let listItemNode = listNode.getFirstChild() as? ListItemNode else {
        XCTFail("List structure not created correctly")
        return
      }

      try listItemNode.remove()
      
      // Check that the list has been replaced with a paragraph
      XCTAssertEqual(rootNode.getChildrenSize(), 1)
      XCTAssertTrue(rootNode.getFirstChild() is ParagraphNode)
    }
  }


  func testGetAttributedStringAttributesWithPlaceholder() throws {
    guard let editor else {
      XCTFail("Editor unexpectedly nil")
      return
    }

    try editor.update {
      guard let rootNode = getActiveEditorState()?.getRootNode() else {
        XCTFail("Root node not found")
        return
      }

      try insertList(editor: editor, listType: .bullet, withPlaceholders: true)

      guard let listNode = rootNode.getFirstChild() as? ListNode,
            let listItemNode = listNode.getFirstChild() as? ListItemNode else {
        XCTFail("List structure not created correctly")
        return
      }

      let theme = editor.getTheme()

      let placeholderAttributes = listItemNode.getAttributedStringAttributes(theme: theme)
      XCTAssertNotNil(placeholderAttributes[.listItem])

      try listItemNode.append([TextNode(text: "Content")])
      let contentAttributes = listItemNode.getAttributedStringAttributes(theme: theme)
      XCTAssertNotNil(contentAttributes[.listItem])
    }
  }

}
