// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

@testable import Lexical
import XCTest

extension NodeType {
  static let testNode = NodeType(rawValue: "testNode")
}

class TestDecoratorNode: DecoratorNode {
  var numberOfTimesDecorateHasBeenCalled = 0

  public required init(numTimes: Int, key: NodeKey? = nil) {
    super.init(key)
    self.numberOfTimesDecorateHasBeenCalled = numTimes
  }

  override init() {
    super.init(nil)
  }

  public required init(_ key: NodeKey?) {
    super.init(key)
  }

  required init(from decoder: Decoder) throws {
    fatalError("init(from:) has not been implemented")
  }

  override public func clone() -> Self {
    Self(numTimes: numberOfTimesDecorateHasBeenCalled, key: key)
  }

  override public func createView() -> UIImageView {
    return UIImageView()
  }

  override public func decorate(view: UIView) {
    getLatest().numberOfTimesDecorateHasBeenCalled += 1
  }

  override public func sizeForDecoratorView(textViewWidth: CGFloat) -> CGSize {
    return CGSize(width: 100, height: 100)
  }
}

class DecoratorNodeTests: XCTestCase {
  func createLexicalView() -> LexicalView {
    return LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
  }

  func testIsDecoratorNode() throws {
    let view = createLexicalView()
    let editor = view.editor

    try editor.update {
      let decoratorNode = DecoratorNode()
      let textNode = TextNode()

      XCTAssert(isDecoratorNode(decoratorNode))
      XCTAssert(!isDecoratorNode(textNode))
    }
  }

  func testDecoratorNodeAddsSubViewOnceOnNodeCreation() throws {
    let view = createLexicalView()
    let editor = view.editor

    try editor.registerNode(nodeType: NodeType.testNode, constructor: { decoder in try TestDecoratorNode(from: decoder) })

    guard let viewForDecoratorSubviews = view.viewForDecoratorSubviews else {
      XCTFail()
      return
    }

    let initialSubViewCount = viewForDecoratorSubviews.subviews.count

    XCTAssertFalse(viewForDecoratorSubviews.subviews.last is UIImageView)

    try editor.update {
      guard let rootNode = getActiveEditorState()?.getRootNode() else {
        XCTFail("No root node")
        return
      }

      let paragraphNode = ParagraphNode()

      let textNode = TextNode()
      try textNode.setText("Hello")

      let decoratorNode = TestDecoratorNode()

      try paragraphNode.append([textNode])
      try paragraphNode.append([decoratorNode])

      try rootNode.append([paragraphNode])
    }

    try editor.update {}
    try editor.update {}
    try editor.update {}

    XCTAssertEqual(viewForDecoratorSubviews.subviews.count, initialSubViewCount + 1)
    XCTAssertTrue(viewForDecoratorSubviews.subviews.last is UIImageView)
  }

  func testDecorateCalledOnlyWhenDirty() throws {
    let view = createLexicalView()
    let editor = view.editor

    try editor.registerNode(nodeType: NodeType.testNode, constructor: { decoder in try TestDecoratorNode(from: decoder) })

    var nodeKey: NodeKey?

    try editor.update {
      guard let rootNode = getActiveEditorState()?.getRootNode() else {
        XCTFail("No root node")
        return
      }

      let paragraphNode = ParagraphNode()

      let decoratorNode = TestDecoratorNode()
      try paragraphNode.append([decoratorNode])
      nodeKey = decoratorNode.getKey()

      try rootNode.append([paragraphNode])
    }

    try editor.read {
      guard let nodeKey = nodeKey, let decoratorNode = getNodeByKey(key: nodeKey) as? TestDecoratorNode else { XCTFail(); return }
      XCTAssertEqual(decoratorNode.numberOfTimesDecorateHasBeenCalled, 1)
    }

    try editor.update {}

    try editor.read {
      guard let nodeKey = nodeKey, let decoratorNode = getNodeByKey(key: nodeKey) as? TestDecoratorNode else { XCTFail(); return }
      XCTAssertEqual(decoratorNode.numberOfTimesDecorateHasBeenCalled, 1, "should still be 1 after an update where nothing changed")
    }

    try editor.update {
      guard let nodeKey = nodeKey, let decoratorNode = getNodeByKey(key: nodeKey) as? TestDecoratorNode else { XCTFail(); return }
      internallyMarkNodeAsDirty(node: decoratorNode, cause: .userInitiated)
    }

    try editor.read {
      guard let nodeKey = nodeKey, let decoratorNode = getNodeByKey(key: nodeKey) as? TestDecoratorNode else { XCTFail(); return }
      XCTAssertEqual(decoratorNode.numberOfTimesDecorateHasBeenCalled, 2, "should be 2 after a dirty update")
    }
  }

  func testDecorateCalledWhenMountingFrontendView() throws {
    let textKitContext = LexicalReadOnlyTextKitContext(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
    let editor = textKitContext.editor

    try editor.registerNode(nodeType: NodeType.testNode, constructor: { decoder in try TestDecoratorNode(from: decoder) })

    var nodeKey: NodeKey?

    try editor.update {
      guard let rootNode = getActiveEditorState()?.getRootNode() else {
        XCTFail("No root node")
        return
      }

      let paragraphNode = ParagraphNode()

      let decoratorNode = TestDecoratorNode()
      try paragraphNode.append([decoratorNode])
      nodeKey = decoratorNode.getKey()

      try rootNode.append([paragraphNode])
    }

    try editor.read {
      guard let nodeKey = nodeKey, let decoratorNode = getNodeByKey(key: nodeKey) as? TestDecoratorNode else { XCTFail(); return }
      XCTAssertEqual(decoratorNode.numberOfTimesDecorateHasBeenCalled, 0)
    }

    try editor.update {
      guard let nodeKey = nodeKey, let decoratorNode = getNodeByKey(key: nodeKey) as? TestDecoratorNode else { XCTFail(); return }
      internallyMarkNodeAsDirty(node: decoratorNode, cause: .userInitiated)
    }

    try editor.read {
      guard let nodeKey = nodeKey, let decoratorNode = getNodeByKey(key: nodeKey) as? TestDecoratorNode else { XCTFail(); return }
      XCTAssertEqual(decoratorNode.numberOfTimesDecorateHasBeenCalled, 0, "should not have decorated as no view created")
    }

    let view = LexicalReadOnlyView()
    view.textKitContext = textKitContext

    try editor.read {
      guard let nodeKey = nodeKey, let decoratorNode = getNodeByKey(key: nodeKey) as? TestDecoratorNode else { XCTFail(); return }
      XCTAssertEqual(decoratorNode.numberOfTimesDecorateHasBeenCalled, 1, "should have automatically called decorate when attaching text kit context")
    }
  }
}
