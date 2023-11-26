/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Lexical
import LexicalHTML
import LexicalListPlugin
import LexicalMarkdown
import UIKit

internal enum OutputFormat: CaseIterable {
  case html
  case json
  case markdown

  var title: String {
    switch self {
    case .html: return "HTML"
    case .json: return "JSON"
    case .markdown: return "Markdown"
    }
  }
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
    case .markdown:
      generateMarkdown(editor: editor)
    }
  }

  required init?(coder: NSCoder) {
    fatalError()
  }

  func generateHTML(editor: Editor) {
    try? editor.read {
      do {
        self.output = try generateHTMLFromNodes(editor: editor, selection: nil)
      } catch let error {
        self.output = error.localizedDescription
      }
    }
  }

  func generateMarkdown(editor: Editor) {
    try? editor.read {
      do {
        self.output = try LexicalMarkdown.generateMarkdown(from: editor, selection: nil)
      } catch let error {
        self.output = error.localizedDescription
      }
    }
  }

  func generateJSON(editor: Editor) {
    let currentEditorState = editor.getEditorState()
    if let jsonString = try? currentEditorState.toJSON() {
      output = jsonString
    } else {
      output = "Failed to generate JSON output"
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
