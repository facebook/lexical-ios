// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import UIKit

public class TextAttachment: NSTextAttachment {
  public var key: NodeKey?
  weak var editor: Editor?
  internal var hasDoneSizeLayout: Bool = false

  override public func attachmentBounds(for _: NSTextContainer?, proposedLineFragment: CGRect, glyphPosition _: CGPoint, characterIndex _: Int) -> CGRect {
    guard let key = key, let editor = editor else {
      return CGRect.zero
    }

    var bounds = CGRect.zero
    try? editor.read {
      guard let decoratorNode = getNodeByKey(key: key) as? DecoratorNode else {
        return
      }
      let size = decoratorNode.sizeForDecoratorView(textViewWidth: editor.frontend?.textLayoutWidth ?? CGFloat(0))
      bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    }
    hasDoneSizeLayout = true
    return bounds
  }

  // necessary to stop UIKit drawing a placeholder image
  override public func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
    return UIImage()
  }
}
