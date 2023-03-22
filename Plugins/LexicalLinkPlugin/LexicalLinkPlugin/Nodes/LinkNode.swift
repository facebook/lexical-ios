// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Lexical
import UIKit

extension NodeType {
  static let link = NodeType(rawValue: "link")
}

open class LinkNode: ElementNode {
  enum CodingKeys: String, CodingKey {
    case url
  }

  public var url: String = ""

  override public init() {
    super.init()
    self.type = NodeType.link
  }

  public required init(url: String, key: NodeKey?) {
    super.init(key)
    self.url = url
    self.type = NodeType.link
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try super.init(from: decoder)

    self.url = try container.decode(String.self, forKey: .url)
    self.type = NodeType.link
  }

  override open func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.url, forKey: .url)
  }

  public func getURL() -> String {
    let latest: LinkNode = getLatest()
    return latest.url
  }

  public func setURL(_ url: String) throws {
    try errorOnReadOnly()
    try getWritable().url = url
  }

  override public func canInsertTextBefore() -> Bool {
    return false
  }

  override public func canInsertTextAfter() -> Bool {
    return false
  }

  override public func canBeEmpty() -> Bool {
    return false
  }

  override public func isInline() -> Bool {
    return true
  }

  override open func clone() -> Self {
    Self(url: url, key: key)
  }

  override public func getAttributedStringAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
    if url.isEmpty {
      return [:]
    }

    var attribs: [NSAttributedString.Key: Any] = theme.link ?? [:]
    attribs[.link] = url
    return attribs
  }

  override open func insertNewAfter(selection: RangeSelection?) throws -> Node? {
    if let element = try getParentOrThrow().insertNewAfter(selection: selection) as? ElementNode {
      let linkNode = LinkNode(url: url, key: nil)
      try element.append([linkNode])
      return linkNode
    }

    return nil
  }
}
