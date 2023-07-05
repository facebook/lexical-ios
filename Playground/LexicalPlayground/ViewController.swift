/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Lexical
import LexicalLinkPlugin
import LexicalInlineImagePlugin
import LexicalListPlugin
import UIKit

class ViewController: UIViewController {

  var lexicalView: LexicalView?
  weak var toolbar: UIToolbar?
  weak var hierarchyView: UIView?
  private let editorStatePersistenceKey = "editorState"

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    let toolbarPlugin = ToolbarPlugin(viewControllerForPresentation: self)
    let toolbar = toolbarPlugin.toolbar

    let hierarchyPlugin = NodeHierarchyViewPlugin()
    let hierarchyView = hierarchyPlugin.hierarchyView

    let listPlugin = ListPlugin()
    let imagePlugin = InlineImagePlugin()

    let linkPlugin = LinkPlugin()

    let theme = Theme()
    theme.indentSize = 40.0
    theme.link = [
      .foregroundColor: UIColor.systemBlue,
    ]

    let editorConfig = EditorConfig(theme: theme, plugins: [toolbarPlugin, listPlugin, hierarchyPlugin, imagePlugin, linkPlugin])
    let lexicalView = LexicalView(editorConfig: editorConfig, featureFlags: FeatureFlags())

    linkPlugin.lexicalView = lexicalView

    self.lexicalView = lexicalView
    self.toolbar = toolbar
    self.hierarchyView = hierarchyView

    self.restoreEditorState()

    view.addSubview(lexicalView)
    view.addSubview(toolbar)
    view.addSubview(hierarchyView)

    navigationItem.title = "Lexical"
    setUpExportMenu()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    if let lexicalView, let toolbar, let hierarchyView {
      let safeAreaInsets = self.view.safeAreaInsets
      let hierarchyViewHeight = 300.0

      toolbar.frame = CGRect(x: 0,
                             y: safeAreaInsets.top,
                             width: view.bounds.width,
                             height: 44)
      lexicalView.frame = CGRect(x: 0,
                                 y: toolbar.frame.maxY,
                                 width: view.bounds.width,
                                 height: view.bounds.height - toolbar.frame.maxY - safeAreaInsets.bottom - hierarchyViewHeight)
      hierarchyView.frame = CGRect(x: 0,
                                   y: lexicalView.frame.maxY,
                                   width: view.bounds.width,
                                   height: hierarchyViewHeight)
    }
  }

  func persistEditorState() {
    guard let editor = lexicalView?.editor else {
      return
    }

    let currentEditorState = editor.getEditorState()

    // turn the editor state into stringified JSON
    guard let jsonString = try? currentEditorState.toJSON() else {
      return
    }

    UserDefaults.standard.set(jsonString, forKey: editorStatePersistenceKey)
  }

  func restoreEditorState() {
    guard let editor = lexicalView?.editor else {
      return
    }

    guard let jsonString = UserDefaults.standard.value(forKey: editorStatePersistenceKey) as? String else {
      return
    }

    // turn the JSON back into a new editor state
    guard let newEditorState = try? EditorState.fromJSON(json: jsonString, editor: editor) else {
      return
    }

    // install the new editor state into editor
    try? editor.setEditorState(newEditorState)
  }

  func setUpExportMenu() {
    let menuItems = [
      UIAction(title: "Export HTML", handler: { action in
        self.showExportScreen(.html)
      }),
      UIAction(title: "Export JSON", handler: { action in
        self.showExportScreen(.json)
      })
    ]
    let menu = UIMenu(title: "Export as…", children: menuItems)
    let barButtonItem = UIBarButtonItem(title: "Export", style: .plain, target: nil, action: nil)
    barButtonItem.menu = menu
    navigationItem.rightBarButtonItem = barButtonItem
  }

  func showExportScreen(_ type: OutputFormat) {
    guard let editor = lexicalView?.editor else { return }
    let vc = ExportOutputViewController(editor: editor, format: type)
    navigationController?.pushViewController(vc, animated: true)
  }
}
