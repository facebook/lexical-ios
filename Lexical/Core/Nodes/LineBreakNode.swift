// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

public class LineBreakNode: Node {
  override public init() {
    super.init()
    self.type = NodeType.linebreak
  }

  override required init(_ key: NodeKey?) {
    super.init(key)
    self.type = NodeType.linebreak
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
    self.type = NodeType.linebreak
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
