// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation
import UIKit

public class NodeSelection: BaseSelection {

  public var nodes: [NodeKey]
  public var dirty: Bool = false

  // MARK: - Init

  public init(nodes: [NodeKey]) {
    self.nodes = nodes
  }

  public func clone() -> BaseSelection {
    return NodeSelection(nodes: nodes)
  }

  public func getNodes() throws -> [Node] {
    return []
  }

  public func extract() throws -> [Node] {
    return []
  }
}
