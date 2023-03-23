/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import Foundation
import Lexical

public enum ListType {
  case bullet
  case number
  case check
}

extension NodeType {
  static let list = NodeType(rawValue: "list")
}

public class ListNode: ElementNode {
  private var listType: ListType = .bullet
  private var start: Int = 1

  public required convenience init(listType: ListType, start: Int, key: NodeKey?) {
    self.init(key)
    self.listType = listType
    self.start = start
  }

  override public init() {
    super.init()
    self.type = NodeType.list
  }

  override public init(_ key: NodeKey?) {
    super.init(key)
    self.type = NodeType.list
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
    self.type = NodeType.list
  }

  // MARK: getters/setters

  public func getListType() -> ListType {
    return getLatest().listType
  }

  @discardableResult
  public func setListType(_ type: ListType) throws -> ListNode {
    let node: ListNode = try getWritable()
    node.listType = type
    return node
  }

  public func getStart() -> Int {
    return getLatest().start
  }

  @discardableResult
  public func setStart(_ start: Int) throws -> ListNode {
    let node: ListNode = try getWritable()
    node.start = start
    return node
  }

  override public func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
  }

  override public func clone() -> Self {
    Self(listType: listType, start: start, key: key)
  }
}
