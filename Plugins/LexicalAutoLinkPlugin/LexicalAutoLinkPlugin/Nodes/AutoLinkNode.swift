/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Lexical
import LexicalLinkPlugin
import UIKit

extension NodeType {
  public static let autoLink = NodeType(rawValue: "autoLink")
}

public class AutoLinkNode: LinkNode {
  enum CodingKeys: String, CodingKey {
    case url
  }

  override public init() {
    super.init()
  }

  required init(url: String, key: NodeKey?) {
    super.init(url: url, key: key)
  }

  override public class func getType() -> NodeType {
    .autoLink
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try super.init(from: decoder)

    self.url = try container.decode(String.self, forKey: .url)
  }

  override open func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.url, forKey: .url)
  }

  override open func clone() -> Self {
    Self(url: url, key: key)
  }

  override open func insertNewAfter(selection: RangeSelection?) throws -> Node? {
    if let element = try getParentOrThrow().insertNewAfter(selection: selection) as? ElementNode {
      let linkNode = AutoLinkNode(url: url, key: nil)
      try element.append([linkNode])
      return linkNode
    }

    return nil
  }
}
