// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation

public protocol BaseSelection {
  var dirty: Bool { get set }
  func clone() -> BaseSelection
  func extract() throws -> [Node]
  func getNodes() throws -> [Node]
}
