/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import AVFoundation
import Foundation
import Lexical
import UIKit

extension NodeType {
  static let image = NodeType(rawValue: "image")
}

extension CommandType {
  public static let imageTap = CommandType(rawValue: "imageTap")
}

public class ImageNode: DecoratorNode {
  var url: URL?
  var size = CGSize.zero
  var sourceID: String = ""

  public override class func getType() -> NodeType {
    return .image
  }

  public required init(url: String, size: CGSize, sourceID: String, key: NodeKey? = nil) {
    super.init(key)

    self.url = URL(string: url)
    self.size = size
    self.sourceID = sourceID
  }

  required init(_ key: NodeKey? = nil) {
    super.init(key)
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
  }
  
  required init(styles: StylesDict, key: NodeKey?) {
    super.init(styles: [:], key: key)
  }
  
  override public func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
  }

  override public func clone() -> Self {
    Self(url: url?.absoluteString ?? "", size: size, sourceID: sourceID, key: key)
  }

  override public func createView() -> UIImageView {
    editorForTapHandling = getActiveEditor()
    let imageView = createImageView()
    loadImage(imageView: imageView)
    return imageView
  }

  override open func decorate(view: UIView) {
    if let view = view as? UIImageView {
      for gr in view.gestureRecognizers ?? [] {
        view.removeGestureRecognizer(gr)
      }
      let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(gestureRecognizer:)))
      view.addGestureRecognizer(gestureRecognizer)
      loadImage(imageView: view)
    }
  }

  public func getURL() -> String? {
    let latest: ImageNode = getLatest()

    return latest.url?.absoluteString
  }

  public func setURL(_ url: String) throws {
    try errorOnReadOnly()

    try getWritable().url = URL(string: url)
  }

  public func getSourceID() -> String? {
    let latest: ImageNode = getLatest()

    return latest.sourceID
  }

  public func setSourceID(_ sourceID: String) throws {
    try errorOnReadOnly()

    try getWritable().sourceID = sourceID
  }

  private func createImageView() -> UIImageView {
    let view = UIImageView(frame: CGRect(origin: CGPoint.zero, size: size))
    view.isUserInteractionEnabled = true

    view.backgroundColor = .lightGray

    return view
  }

  private weak var editorForTapHandling: Editor?
  @objc internal func handleTap(gestureRecognizer: UITapGestureRecognizer) {
    guard let editorForTapHandling else { return }
    do {
      try editorForTapHandling.update {
        editorForTapHandling.dispatchCommand(type: .imageTap, payload: getSourceID())
      }
    } catch {
      editorForTapHandling.log(.node, .error, "Error thrown in tap handler, \(error)")
    }
  }

  private func loadImage(imageView: UIImageView) {
    guard let url else { return }

    URLSession.shared.dataTask(with: url) { (data, response, error) in
      if error != nil {
        return
      }

      guard let data else {
        return
      }

      DispatchQueue.main.async {
        imageView.image = UIImage(data: data)
      }
    }.resume()
  }

  let maxImageHeight: CGFloat = 600.0

  override open func sizeForDecoratorView(textViewWidth: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGSize {

    if size.width <= textViewWidth {
      return size
    }
    return AVMakeRect(aspectRatio: size, insideRect: CGRect(x: 0, y: 0, width: textViewWidth, height: maxImageHeight)).size
  }
}
