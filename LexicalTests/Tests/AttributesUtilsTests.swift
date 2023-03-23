/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

@testable import Lexical
import XCTest

class AttributesUtilsTests: XCTestCase {
  func testGetLexicalAttributes() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let textNode = TextNode()
      try textNode.setText("hello world")

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])

      guard let editorState = getActiveEditorState(),
            let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])

      let attributes = AttributeUtils.getLexicalAttributes(
        from: textNode,
        state: editorState,
        theme: editor.getTheme()
      )

      for attributeDict in attributes {
        if let font = attributeDict[.font] as? UIFont {
          XCTAssertTrue(font.familyName == "Helvetica", "Node font attribute is incorrect")
        }
      }
    }
  }

  private func firstFontInAttributedString(attrStr: NSAttributedString) -> UIFont {
    let font = attrStr.attribute(.font, at: 0, effectiveRange: nil)
    return font as? UIFont ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
  }

  func testattributedStringByAddingStyles() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let textNode = TextNode()
      try textNode.setText("hello world")

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])

      guard let editorState = getActiveEditorState(),
            let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])

      let attributedString = NSMutableAttributedString(string: textNode.getTextPart())

      let styledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let font = firstFontInAttributedString(attrStr: styledAttrStr)

      XCTAssertTrue(font.familyName == "Helvetica", "TextNode's attributes should take priority over all parent node's attributes")
    }
  }

  func testApplyBoldStyles() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let textNode = TextNode()
      try textNode.setText("hello world")
      textNode.format.bold = true

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])

      guard let editorState = getActiveEditorState(),
            let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])
      let attributedString = NSMutableAttributedString(string: textNode.getTextPart())
      let styledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let font = firstFontInAttributedString(attrStr: styledAttrStr)

      XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold), "Font should contain the bold trait")

      textNode.format.bold = false
      // let attributedString = NSMutableAttributedString(string: textNode.getTextPart())
      let newStyledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let newFont = firstFontInAttributedString(attrStr: newStyledAttrStr)

      XCTAssertFalse(newFont.fontDescriptor.symbolicTraits.contains(.traitBold), "Font should not contain the bold trait")
    }
  }

  func testApplyItalicStyles() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let textNode = TextNode()
      try textNode.setText("hello world")
      textNode.format.italic = true

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])

      guard let editorState = getActiveEditorState(),
            let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])
      let attributedString = NSMutableAttributedString(string: textNode.getTextPart())
      let styledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let font = firstFontInAttributedString(attrStr: styledAttrStr)

      XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic), "Font should contain the italic trait")

      textNode.format.italic = false
      let newStyledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let newFont = firstFontInAttributedString(attrStr: newStyledAttrStr)

      XCTAssertFalse(newFont.fontDescriptor.symbolicTraits.contains(.traitItalic), "Font should not contain the italic trait")
    }
  }

  func testApplyBoldAndItalicStyles() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let textNode = TextNode()
      try textNode.setText("hello world")
      textNode.format.bold = true
      textNode.format.italic = true

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([textNode])

      guard let editorState = getActiveEditorState(),
            let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])
      let attributedString = NSMutableAttributedString(string: textNode.getTextPart())
      let styledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let font = firstFontInAttributedString(attrStr: styledAttrStr)

      XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold), "Font should contain the bold trait")
      XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic), "Font should contain the italic trait")

      textNode.format.bold = false
      let newStyledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: textNode, state: editorState, theme: editor.getTheme())
      let newFont = firstFontInAttributedString(attrStr: newStyledAttrStr)

      XCTAssertFalse(newFont.fontDescriptor.symbolicTraits.contains(.traitBold), "Font should not contain the bold trait")
      XCTAssertTrue(newFont.fontDescriptor.symbolicTraits.contains(.traitItalic), "Font should contain the italic trait")
    }
  }

  func testFontUpdate() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor
    try editor.update {
      let testAttributeNode = TestAttributesNode()

      let paragraphNode = ParagraphNode()
      try paragraphNode.append([testAttributeNode])

      guard let editorState = getActiveEditorState(),
            let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])

      let attributedString = NSMutableAttributedString(string: "Hello World")
      let styledAttrStr = AttributeUtils.attributedStringByAddingStyles(attributedString, from: testAttributeNode, state: editorState, theme: editor.getTheme())
      let font = firstFontInAttributedString(attrStr: styledAttrStr)

      XCTAssertEqual(font.familyName, "Arial", "Font attribute is incorrect")
      XCTAssertTrue(font.pointSize == 10, "Font size is incorrect")
      XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold), "Font should not contain the bold trait")
    }
  }

  func testThemeForRootNode() throws {
    let rootAttributes: [NSAttributedString.Key: Any] = [
      .fontFamily: "Arial",
      .fontSize: 18 as Float
    ]

    let theme = Theme()
    theme.root = rootAttributes
    let view = LexicalView(editorConfig: EditorConfig(theme: theme, plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let paragraphNode = ParagraphNode()
      let textNode = TextNode()
      try textNode.setText("Testing Theme!")

      try paragraphNode.append([textNode])

      guard let editorState = getActiveEditorState(),
            let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([paragraphNode])
    }

    let attributedString = view.textView.attributedText
    if let attribute = attributedString?.attribute(.font, at: 1, effectiveRange: nil) as? UIFont {
      XCTAssertEqual(attribute.familyName, "Arial")
      XCTAssertEqual(attribute.pointSize, 18)
    }
  }

  func testThemeForHeadingNode() throws {
    let view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = view.editor

    try editor.update {
      let headingNode = HeadingNode(tag: .h1)
      let textNode = TextNode()
      try textNode.setText("Testing HeadingNode!")

      try headingNode.append([textNode])
      guard let editorState = getActiveEditorState(),
            let rootNode: RootNode = try editorState.getRootNode()?.getWritable()
      else {
        XCTFail("should have editor state")
        return
      }

      try rootNode.append([headingNode])
    }

    let attributedString = view.textView.attributedText
    if let attribute = attributedString?.attribute(.font, at: 1, effectiveRange: nil) as? UIFont {
      XCTAssertEqual(attribute.familyName, "Helvetica")
      XCTAssertEqual(attribute.pointSize, 36)
    }
  }
}
