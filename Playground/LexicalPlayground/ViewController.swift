/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Lexical
import UIKit

class ViewController: UIViewController {

  var lexicalView: LexicalView?
  weak var toolbar: UIToolbar?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    let toolbarPlugin = ToolbarPlugin(viewControllerForPresentation: self)
    let toolbar = toolbarPlugin.toolbar

    let theme = Theme()
    let editorConfig = EditorConfig(theme: theme, plugins: [toolbarPlugin])
    let lexicalView = LexicalView(editorConfig: editorConfig, featureFlags: FeatureFlags())

    self.lexicalView = lexicalView
    self.toolbar = toolbar

    view.addSubview(lexicalView)
    view.addSubview(toolbar)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    if let lexicalView, let toolbar {
      let safeAreaInsets = self.view.safeAreaInsets

      toolbar.frame = CGRect(x: 0,
                             y: safeAreaInsets.top,
                             width: view.bounds.width,
                             height: 44)
      lexicalView.frame = CGRect(x: 0,
                                 y: toolbar.frame.maxY,
                                 width: view.bounds.width,
                                 height: view.bounds.height - toolbar.frame.maxY - safeAreaInsets.bottom)
    }
  }
}
