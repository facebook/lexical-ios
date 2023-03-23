/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

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
