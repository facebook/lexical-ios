/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

@testable import Lexical
import XCTest

class SerializationTests: XCTestCase {

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
    view = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
  }

  override func tearDown() {
    view = nil
  }

  func testBuiltinNodeMap() throws {
    let mapping = makeDeserializationMap()

    XCTAssertNotNil(mapping[NodeType.text], "Text Node should not be nil")
    XCTAssertNotNil(mapping[NodeType.paragraph], "Paragraph Node should not be nil")
    XCTAssertNotNil(mapping[NodeType.root], "Root Node should not be nil")
    XCTAssertNotNil(mapping[NodeType.element], "Element Node should not be nil")
    XCTAssertNotNil(mapping[NodeType.quote], "Quote Node should not be nil")
    XCTAssertNotNil(mapping[NodeType.heading], "Heading Node should not be nil")
  }

  func testSimpleSerialization() throws {
    try editor.update {
      guard let editorState = getActiveEditorState(),
            let rootNode = editorState.getRootNode()
      else {
        XCTFail("should have editor state")
        return
      }

      guard let paragraphNode = rootNode.getFirstChild() as? ParagraphNode else {
        XCTFail()
        return
      }

      let textNode = TextNode(text: "Hello")
      try paragraphNode.append([textNode])
    }

    try editor.update {
      let nodes = try generateArrayFromSelectedNodes(editor: editor, selection: nil).nodes

      let encoder = JSONEncoder()
      let decoder = JSONDecoder()

      let result: Data = try encoder.encode(nodes)

      XCTAssertNotNil(result)

      let newSerialization: SerializedNodeArray = try decoder.decode(SerializedNodeArray.self, from: result)
      XCTAssertEqual(newSerialization.nodeArray.count, 1)
      XCTAssertEqual((newSerialization.nodeArray[0] as? ElementNode)?.children.count, 1)

      guard let textNode = (newSerialization.nodeArray[0] as? ElementNode)?.getChildren()[0] as? TextNode else {
        XCTFail("Could not find TextNode")
        return
      }

      XCTAssertEqual(textNode.getTextContent(), "Hello")
    }
  }

  let jsonString = "{\"root\":{\"children\":[{\"children\":[{\"detail\":0,\"format\":0,\"mode\":\"normal\",\"style\":\"\",\"text\":\"This is \",\"type\":\"text\",\"version\":1},{\"detail\":0,\"format\":1,\"mode\":\"normal\",\"style\":\"\",\"text\":\"bold\",\"type\":\"text\",\"version\":1},{\"detail\":0,\"format\":0,\"mode\":\"normal\",\"style\":\"\",\"text\":\" \",\"type\":\"text\",\"version\":1},{\"detail\":0,\"format\":2,\"mode\":\"normal\",\"style\":\"\",\"text\":\"italic\",\"type\":\"text\",\"version\":1},{\"detail\":0,\"format\":0,\"mode\":\"normal\",\"style\":\"\",\"text\":\" \",\"type\":\"text\",\"version\":1},{\"detail\":0,\"format\":8,\"mode\":\"normal\",\"style\":\"\",\"text\":\"underline\",\"type\":\"text\",\"version\":1},{\"detail\":0,\"format\":0,\"mode\":\"normal\",\"style\":\"\",\"text\":\" text in the first paragraph.\",\"type\":\"text\",\"version\":1}],\"direction\":\"ltr\",\"format\":\"\",\"indent\":0,\"type\":\"paragraph\",\"version\":1},{\"children\":[{\"detail\":0,\"format\":0,\"mode\":\"normal\",\"style\":\"\",\"text\":\"This is another paragraph.\",\"type\":\"text\",\"version\":1}],\"direction\":\"ltr\",\"format\":\"\",\"indent\":0,\"type\":\"paragraph\",\"version\":1},{\"children\":[{\"detail\":0,\"format\":16,\"mode\":\"normal\",\"style\":\"\",\"text\":\"This is a code line.\",\"type\":\"text\",\"version\":1}],\"direction\":\"ltr\",\"format\":\"\",\"indent\":0,\"type\":\"paragraph\",\"version\":1},{\"children\":[{\"detail\":0,\"format\":0,\"mode\":\"normal\",\"style\":\"\",\"text\":\"This is \",\"type\":\"text\",\"version\":1},{\"detail\":0,\"format\":4,\"mode\":\"normal\",\"style\":\"\",\"text\":\"strikethrough\",\"type\":\"text\",\"version\":1}],\"direction\":\"ltr\",\"format\":\"\",\"indent\":0,\"type\":\"paragraph\",\"version\":1}],\"direction\":\"ltr\",\"format\":\"\",\"indent\":0,\"type\":\"root\",\"version\":1}}"

  func testWebFormatJSONImporting() throws {
    try editor.update {
      let decoder = JSONDecoder()
      do {
        let decodedNodeArray = try decoder.decode(SerializedEditorState.self, from: (jsonString.data(using: .utf8) ?? Data()))

        guard let rootNode = decodedNodeArray.rootNode else {
          XCTFail("Failed to decode RootNode")
          return
        }
        guard let selection = try getSelection() as? RangeSelection else {
          XCTFail("Could not get selection")
          return
        }

        _ = try insertGeneratedNodes(editor: editor, nodes: rootNode.getChildren(), selection: selection)

      } catch {
        XCTFail("Error in decoding \(error)")
      }
    }

    try editor.read {
      guard let rootNode = getRoot() else {
        XCTFail("No root")
        return
      }
      let children = rootNode.children
      XCTAssertEqual(children.count, 4)

      guard let firstParagraph = rootNode.getChildren()[0] as? ParagraphNode else {
        XCTFail("Could not get first ParagraphNode")
        return
      }
      XCTAssertEqual(firstParagraph.children.count, 7)
      XCTAssertEqual(firstParagraph.getTextContent(), "This is bold italic underline text in the first paragraph.\n")
      XCTAssertTrue((firstParagraph.getChildren()[1] as? TextNode)?.getStyle(Styles.Bold.self) ?? false)
      XCTAssertTrue((firstParagraph.getChildren()[3] as? TextNode)?.getStyle(Styles.Italic.self) ?? false)
      XCTAssertTrue((firstParagraph.getChildren()[5] as? TextNode)?.getStyle(Styles.Underline.self) ?? false)

      guard let secondPargraph = rootNode.getChildren()[1] as? ParagraphNode else {
        XCTFail("Could not get second ParagraphNode")
        return
      }
      XCTAssertEqual(secondPargraph.children.count, 1)
      XCTAssertEqual(secondPargraph.getTextContent(), "This is another paragraph.\n")

      let childrenSize = rootNode.getChildrenSize()
      guard childrenSize >= 3, let thirdParagraph = rootNode.getChildren()[2] as? ParagraphNode else {
        XCTFail("Could not get third ParagraphNode")
        return
      }
      XCTAssertEqual(thirdParagraph.children.count, 1)
      XCTAssertEqual(thirdParagraph.getTextContent(), "This is a code line.\n")
      XCTAssertTrue((thirdParagraph.getChildren().first as? TextNode)?.getStyle(Styles.Code.self) ?? false)

      guard let fourthParagraph = rootNode.getChildren()[3] as? ParagraphNode else {
        XCTFail("Could not get fourth ParagraphNode")
        return
      }
      XCTAssertEqual(fourthParagraph.children.count, 2)
      XCTAssertEqual(fourthParagraph.getTextContent(), "This is strikethrough")
      XCTAssertTrue((fourthParagraph.getChildren().last as? TextNode)?.getStyle(Styles.Strikethrough.self) ?? false)
    }
  }

  func testGetTextOutOfJSONHeadlessly() throws {
    let headlessEditor = Editor.createHeadless(editorConfig: EditorConfig(theme: Theme(), plugins: []))

    var text: String?

    try headlessEditor.update {
      let decodedNodeArray = try JSONDecoder().decode(SerializedEditorState.self, from: (jsonString.data(using: .utf8) ?? Data()))

      guard let rootNode = decodedNodeArray.rootNode else {
        XCTFail("Failed to decode RootNode")
        return
      }

      guard let selection = try getSelection() as? RangeSelection else {
        XCTFail("Could not get selection")
        return
      }

      try insertGeneratedNodes(editor: headlessEditor, nodes: rootNode.getChildren(), selection: selection)

      text = getRoot()?.getTextContent()
    }

    XCTAssertEqual(text, "This is bold italic underline text in the first paragraph.\nThis is another paragraph.\nThis is a code line.\nThis is strikethrough")
  }

  let roundtripJSONWithStyles = "{\"root\":{\"direction\":\"ltr\",\"indent\":0,\"children\":[{\"type\":\"paragraph\",\"children\":[{\"type\":\"text\",\"mode\":\"normal\",\"text\":\"This is \",\"detail\":0,\"version\":1},{\"detail\":0,\"type\":\"text\",\"mode\":\"normal\",\"text\":\"bold\",\"styles\":{\"bold\":true},\"version\":1},{\"text\":\" \",\"version\":1,\"type\":\"text\",\"mode\":\"normal\",\"detail\":0},{\"styles\":{\"italic\":true},\"version\":1,\"text\":\"italic\",\"mode\":\"normal\",\"detail\":0,\"type\":\"text\"},{\"mode\":\"normal\",\"text\":\" \",\"detail\":0,\"version\":1,\"type\":\"text\"},{\"type\":\"text\",\"detail\":0,\"styles\":{\"underline\":true},\"text\":\"underline\",\"version\":1,\"mode\":\"normal\"},{\"text\":\" text in the first paragraph.\",\"version\":1,\"type\":\"text\",\"mode\":\"normal\",\"detail\":0}],\"indent\":0,\"direction\":\"ltr\",\"version\":1},{\"version\":1,\"children\":[{\"type\":\"text\",\"detail\":0,\"text\":\"This is another paragraph.\",\"version\":1,\"mode\":\"normal\"}],\"direction\":\"ltr\",\"indent\":0,\"type\":\"paragraph\"},{\"direction\":\"ltr\",\"children\":[{\"detail\":0,\"text\":\"This is a code line.\",\"version\":1,\"styles\":{\"code\":true},\"type\":\"text\",\"mode\":\"normal\"}],\"indent\":0,\"version\":1,\"type\":\"paragraph\"},{\"version\":1,\"direction\":\"ltr\",\"indent\":0,\"type\":\"paragraph\",\"children\":[{\"detail\":0,\"text\":\"This is \",\"type\":\"text\",\"version\":1,\"mode\":\"normal\"},{\"type\":\"text\",\"text\":\"strikethrough\",\"mode\":\"normal\",\"detail\":0,\"version\":1,\"styles\":{\"strikethrough\":true}}]}],\"type\":\"root\",\"version\":1}}"

  func testFromToJSONMethods() throws {
    let headlessEditor = Editor.createHeadless(editorConfig: EditorConfig(theme: Theme(), plugins: []))
    let editorState = try EditorState.fromJSON(json: roundtripJSONWithStyles, editor: headlessEditor)

    try headlessEditor.read {
      XCTAssertEqual(getRoot()?.getTextContent(), "", "Expected empty string")
    }

    try editorState.read {
      let text = getRoot()?.getTextContent()
      XCTAssertEqual(text, "This is bold italic underline text in the first paragraph.\nThis is another paragraph.\nThis is a code line.\nThis is strikethrough", "Expected text in new editor state")
    }

    try headlessEditor.setEditorState(editorState)

    var jsonResult: String = ""
    try headlessEditor.read {
      let text = getRoot()?.getTextContent()
      XCTAssertEqual(text, "This is bold italic underline text in the first paragraph.\nThis is another paragraph.\nThis is a code line.\nThis is strikethrough", "Expected text in editor")
      jsonResult = try editorState.toJSON()
    }

    // test json equality
    guard let comparisonJSONData = roundtripJSONWithStyles.data(using: .utf8), let outputJSONData = jsonResult.data(using: .utf8) else {
      XCTFail("couldn't convert to data")
      return
    }

    guard let comparisonJSON = try? JSONSerialization.jsonObject(with: comparisonJSONData) as? NSDictionary, let outputJSON = try? JSONSerialization.jsonObject(with: outputJSONData) as? NSDictionary else {
      XCTFail("Could not json decode")
      return
    }

    XCTAssertEqual(comparisonJSON, outputJSON, "Equality of json")
  }
}
