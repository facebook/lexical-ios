/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import UIKit

public class NodeSelection: BaseSelection {

  public var nodes: Set<NodeKey>
  public var dirty: Bool = false

  public init(nodes: Set<NodeKey>) {
    self.nodes = nodes
  }

  public func clone() -> BaseSelection {
    return NodeSelection(nodes: nodes)
  }

  public func add(key: NodeKey) {
    dirty = true
    nodes.insert(key)
  }

  public func delete(key: NodeKey) {
    dirty = true
    nodes.remove(key)
  }

  public func clear() {
    dirty = true
    nodes.removeAll()
  }

  public func has(key: NodeKey) -> Bool {
    return nodes.contains(key)
  }

  public func getNodes() throws -> [Node] {
    let objects = self.nodes
    var nodesToReturn: [Node] = []
    for object in objects {
      if let node = getNodeByKey(key: object) {
        nodesToReturn.append(node)
      }
    }
    return nodesToReturn
  }

  public func extract() throws -> [Node] {
    return try getNodes()
  }

  public func getTextContent() throws -> String {
    let nodes = try getNodes()
    var textContent = ""
    for node in nodes {
      textContent.append(node.getTextContent())
    }
    return textContent
  }

  public func insertRawText(_ text: String) {
    // do nothing
  }

  public func isSelection(_ selection: BaseSelection) -> Bool {
    guard let selection = selection as? NodeSelection else {
      return false
    }
    return nodes == selection.nodes
  }

  public func insertNodes(nodes: [Node], selectStart: Bool = false) throws -> Bool {
    // TODO
    return false
  }
}

extension NodeSelection: CustomDebugStringConvertible {
  public var debugDescription: String {
    return "Node Selection"
  }
}
