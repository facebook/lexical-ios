/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import CoreGraphics
import Foundation
import Lexical

extension NSAttributedString.Key {
  public static let listItem: NSAttributedString.Key = .init(rawValue: "list_item")
  public static let checkedListItem: NSAttributedString.Key = .init(rawValue: "checked_list_item")
  public static let checkRectHeight: NSAttributedString.Key = .init(rawValue: "check_rect_height")
  public static let checkSymbolName: NSAttributedString.Key = .init(rawValue: "check_symbol_name")
}

internal struct ListItemAttribute: Hashable, Equatable {
  // Node key is to make sure that consecutive list items have list item attributes that are not equal
  var itemNodeKey: NodeKey

  var listItemCharacter: String
  var characterIndentationPixels: CGFloat
  var listType: ListType
  var isChecked: Bool
}
