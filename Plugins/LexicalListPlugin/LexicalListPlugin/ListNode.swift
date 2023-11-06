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

@LexicalNode(.list)
public class ListNode: ElementNode {
  private var _listType: ListType = .bullet
  private var _start: Int = 1
}
