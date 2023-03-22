// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation

public enum HeadingTagType: Codable {
  case h1
  case h2
  case h3
  case h4
  case h5
}

enum HeadingDefaultFontSize: Float {
  case h1 = 36
  case h2 = 32
  case h3 = 28
  case h4 = 24
  case h5 = 20
}

public class HeadingNode: ElementNode {
  enum CodingKeys: String, CodingKey {
    case tag
  }

  private var tag: HeadingTagType

  // MARK: - Init

  public init(tag: HeadingTagType) {
    self.tag = tag

    super.init()
    self.type = NodeType.heading
  }

  public required init(_ key: NodeKey?, tag: HeadingTagType) {
    self.tag = tag
    super.init(key)
    self.type = NodeType.heading
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.tag = try container.decode(HeadingTagType.self, forKey: .tag)
    try super.init(from: decoder)

    self.type = NodeType.heading
  }

  override public func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.tag, forKey: .tag)
  }

  public func getTag() -> HeadingTagType {
    tag
  }

  override public func clone() -> Self {
    Self(key, tag: tag)
  }

  override public func getAttributedStringAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
    switch tag {
    case .h1:
      return theme.getValue(.heading, withSubtype: "h1") ?? [.fontSize: HeadingDefaultFontSize.h1.rawValue]
    case .h2:
      return theme.getValue(.heading, withSubtype: "h2") ?? [.fontSize: HeadingDefaultFontSize.h2.rawValue]
    case .h3:
      return theme.getValue(.heading, withSubtype: "h3") ?? [.fontSize: HeadingDefaultFontSize.h3.rawValue]
    case .h4:
      return theme.getValue(.heading, withSubtype: "h4") ?? [.fontSize: HeadingDefaultFontSize.h4.rawValue]
    case .h5:
      return theme.getValue(.heading, withSubtype: "h5") ?? [.fontSize: HeadingDefaultFontSize.h5.rawValue]
    }
  }

  // MARK: - Mutation

  override open func insertNewAfter(selection: RangeSelection?) throws -> Node? {
    let newElement = createParagraphNode()

    try newElement.setDirection(direction: getDirection())
    try insertAfter(nodeToInsert: newElement)

    return newElement
  }

  override func collapseAtStart(selection: RangeSelection) throws -> Bool {
    let paragraph = createParagraphNode()

    try getChildren().forEach { node in
      try paragraph.append([node])
    }

    try replace(replaceWith: paragraph)

    return true
  }
}
