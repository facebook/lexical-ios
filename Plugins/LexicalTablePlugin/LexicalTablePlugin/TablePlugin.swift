// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation
import Lexical

extension CommandType {
  public static let tableNodeEditorConfig = CommandType(rawValue: "tableNodeEditorConfig")
}

public typealias EditorConfigFactory = () -> EditorConfig

public class TablePlugin: Plugin {
  public init(editorConfigFactory: @escaping EditorConfigFactory) {
    self.editorConfigFactory = editorConfigFactory
  }

  weak var editor: Editor?

  internal var editorConfigFactory: EditorConfigFactory

  public func setUp(editor: Editor) {
    self.editor = editor

    do {
      try editor.registerNode(nodeType: NodeType.table, constructor: { decoder in try TableNode(from: decoder) })
    } catch {
      editor.log(.other, .error, "\(error)")
    }
  }

  public func tearDown() {}
}
