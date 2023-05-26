/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Lexical
import LexicalHTML
import LexicalListPlugin
import UIKit

internal enum OutputFormat {
  case html
  case json
}

class ExportOutputViewController: UIViewController {
  var output: String = ""

  init(editor: Editor, format: OutputFormat) {
    super.init(nibName: nil, bundle: nil)
    switch format {
    case .html:
      generateHTML(editor: editor)
    case .json:
      generateJSON(editor: editor)
    }
  }

  required init?(coder: NSCoder) {
    fatalError()
  }

  func generateHTML(editor: Editor) {
    try? editor.read {
      self.output = try generateHTMLFromNodes(editor: editor, selection: nil)
    }
  }

  func generateJSON(editor: Editor) {
    let currentEditorState = editor.getEditorState()
    if let jsonString = try? currentEditorState.toJSON() {
      output = jsonString
    }
  }

  override func loadView() {
    super.loadView()

    let textView = UITextView(frame: view.bounds)
    textView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    textView.isEditable = false
    textView.text = output
    view.addSubview(textView)
  }
}
