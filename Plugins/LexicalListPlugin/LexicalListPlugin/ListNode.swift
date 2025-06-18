/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical

public enum ListType: String, Codable {
  case bullet
  case number
  case check
}

extension NodeType {
  public static let list = NodeType(rawValue: "list")
}

public class ListNode: ElementNode {
  enum CodingKeys: String, CodingKey {
    case listType
    case start
  }

  private var listType: ListType = .bullet
  private var start: Int = 1

  public required convenience init(listType: ListType, start: Int, key: NodeKey? = nil) {
    self.init(key)
    self.listType = listType
    self.start = start
  }

  override public init() {
    super.init()
  }

  override public init(_ key: NodeKey?) {
    super.init(key)
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try super.init(from: decoder)
    
    self.listType = try container.decode(ListType.self, forKey: .listType)
    self.start = try container.decode(Int.self, forKey: .start)
  }
  override public class func getType() -> NodeType {
    return .list
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

  override public func clone() -> Self {
    Self(listType: listType, start: start, key: key)
  }
}
