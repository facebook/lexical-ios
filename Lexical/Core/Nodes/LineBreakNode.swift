/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

public class LineBreakNode: Node {
  required public init(styles: StylesDict, key: NodeKey?) {
    super.init(styles: styles, key: key)
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
  }

  public override class func getType() -> NodeType {
    .linebreak
  }

  override public func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
  }

  override public func clone() -> Self {
    Self(styles: styles, key: key)
  }

  override public func getPostamble() -> String {
    return "\n"
  }

  public func createLineBreakNode() -> LineBreakNode {
    return LineBreakNode(styles: [:], key: nil)
  }
}
