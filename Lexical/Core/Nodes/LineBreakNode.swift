/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

public class LineBreakNode: Node {

  open override class var type: NodeType {
    .linebreak
  }

  override public init() {
    super.init()
  }

  override required init(_ key: NodeKey?) {
    super.init(key)
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
  }

  override public func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
  }

  override public func clone() -> Self {
    Self(key)
  }

  override public func getPostamble() -> String {
    return "\n"
  }

  public func createLineBreakNode() -> LineBreakNode {
    return LineBreakNode()
  }
}
