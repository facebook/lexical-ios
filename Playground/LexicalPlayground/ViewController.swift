/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Lexical
import LexicalListPlugin
//import LexicalHTML
import UIKit

class ViewController: UIViewController {

  var lexicalView: LexicalView?
  weak var toolbar: UIToolbar?
  weak var hierarchyView: UIView?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    let toolbarPlugin = ToolbarPlugin(viewControllerForPresentation: self)
    let toolbar = toolbarPlugin.toolbar

    let hierarchyPlugin = NodeHierarchyViewPlugin()
    let hierarchyView = hierarchyPlugin.hierarchyView

    let listPlugin = ListPlugin()

    let theme = Theme()
    theme.indentSize = 40.0
    let editorConfig = EditorConfig(theme: theme, plugins: [toolbarPlugin, listPlugin, hierarchyPlugin])
    let lexicalView = LexicalView(editorConfig: editorConfig, featureFlags: FeatureFlags())

    self.lexicalView = lexicalView
    self.toolbar = toolbar
    self.hierarchyView = hierarchyView

    view.addSubview(lexicalView)
    view.addSubview(toolbar)
    view.addSubview(hierarchyView)
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
}
