/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

public protocol BaseSelection: AnyObject, CustomDebugStringConvertible {
  var dirty: Bool { get set }
  func clone() -> BaseSelection
  func extract() throws -> [Node]
  func getNodes() throws -> [Node]
  func getTextContent() throws -> String
  func insertRawText(_ text: String) throws
  func isSelection(_ selection: BaseSelection) -> Bool
}
