/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical
import LexicalListPlugin
import UIKit

public class NodeHierarchyViewPlugin: Plugin {
  private var _hierarchyView: UITextView

  weak var editor: Editor?

  init() {
    self._hierarchyView = UITextView()
    _hierarchyView.backgroundColor = .black
    _hierarchyView.layer.borderColor = UIColor.systemGray.cgColor
    _hierarchyView.textColor = .white
    _hierarchyView.isEditable = false
    _hierarchyView.isUserInteractionEnabled = true
    _hierarchyView.isScrollEnabled = true
    _hierarchyView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    _hierarchyView.showsVerticalScrollIndicator = true
  }

  // MARK: - Plugin API

  public func setUp(editor: Editor) {
    self.editor = editor

    _ = editor.registerUpdateListener { [weak self] activeEditorState, previousEditorState, dirtyNodes in
      if let self {
        self.updateHierarchyView(editorState: activeEditorState)
      }
    }
  }

  public func tearDown() {
  }

  public var hierarchyView: UIView {
    get {
      _hierarchyView
    }
  }

  // MARK: -

  private func updateHierarchyView(editorState: EditorState) {
    do {
      let hierarchyString = try getNodeHierarchy(editorState: editorState)
      let selectionString = try getSelectionData(editorState: editorState)
      _hierarchyView.text = "\(hierarchyString)\n\n\(selectionString)"
    } catch {
      print("Error updating node hierarchy.")
    }
  }
}
