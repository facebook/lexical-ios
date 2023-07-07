/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Lexical

public class SelectableDecoratorView: UIView {
  public weak var editor: Editor?
  public var nodeKey: NodeKey?

  public var contentView: UIView? {
    didSet {
      if let oldValue, oldValue != contentView {
        oldValue.removeFromSuperview()
      }
      if let contentView {
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      }
    }
  }

  var updateListener: Editor.RemovalHandler?
  var gestureRecognizer: UITapGestureRecognizer?
  var borderView: UIView = UIView(frame: .zero)

  internal func setUpListeners() throws {
    guard let editor, let nodeKey, gestureRecognizer == nil else {
      throw LexicalError.invariantViolation("expected editor and node key by now")
    }
    updateListener = editor.registerUpdateListener() { [weak self] activeEditorState, previousEditorState, dirtyNodes in
      try? activeEditorState.read {
        let selection = try getSelection()
        if let selection = selection as? NodeSelection {
          let nodes = try selection.getNodes().map { node in
            node.getKey()
          }
          self?.setDrawsSelectionBorder(nodes.contains(nodeKey))
        } else {
          self?.setDrawsSelectionBorder(false)
        }
      }
    }

    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapReceived(sender:)))
    self.addGestureRecognizer(gestureRecognizer)
    self.gestureRecognizer = gestureRecognizer

    addSubview(borderView)
    borderView.frame = self.bounds
    borderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    borderView.isUserInteractionEnabled = false
    borderView.layer.borderColor = UIColor.red.cgColor
    borderView.layer.borderWidth = 2.0
    borderView.isHidden = true
  }

  @objc private func tapReceived(sender: UITapGestureRecognizer) {
    if sender.state == .ended {
      try? editor?.update {
        var selection = try getSelection()
        if !(selection is NodeSelection) {
          let nodeSelection = NodeSelection(nodes: Set())
          getActiveEditorState()?.selection = nodeSelection
          selection = nodeSelection
        }
        guard let selection = selection as? NodeSelection, let nodeKey else {
          throw LexicalError.invariantViolation("Expected node selection by now")
        }
        selection.add(key: nodeKey)
      }
    }
  }

  private var drawsSelectionBorder: Bool = false
  private func setDrawsSelectionBorder(_ isSelected: Bool) {
    self.drawsSelectionBorder = isSelected
    borderView.isHidden = !isSelected
  }

  deinit {
    if let updateListener {
      updateListener()
    }
  }
}
