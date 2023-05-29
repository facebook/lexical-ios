/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit
import Lexical

class SelectableDecoratorView: UIView {
  public weak var editor: Editor?

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
}
