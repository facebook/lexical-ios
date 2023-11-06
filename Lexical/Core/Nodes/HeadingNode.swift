/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

public enum HeadingTagType: String, Codable {
  case h1
  case h2
  case h3
  case h4
  case h5
}

enum HeadingDefaultFontSize: Float {
  case h1 = 36
  case h2 = 32
  case h3 = 28
  case h4 = 24
  case h5 = 20
}

@LexicalNode(.heading)
public class HeadingNode: ElementNode {

  private var _tag: HeadingTagType

  override public func getAttributedStringAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
    switch tag {
    case .h1:
      return theme.getValue(.heading, withSubtype: "h1") ?? [.fontSize: HeadingDefaultFontSize.h1.rawValue]
    case .h2:
      return theme.getValue(.heading, withSubtype: "h2") ?? [.fontSize: HeadingDefaultFontSize.h2.rawValue]
    case .h3:
      return theme.getValue(.heading, withSubtype: "h3") ?? [.fontSize: HeadingDefaultFontSize.h3.rawValue]
    case .h4:
      return theme.getValue(.heading, withSubtype: "h4") ?? [.fontSize: HeadingDefaultFontSize.h4.rawValue]
    case .h5:
      return theme.getValue(.heading, withSubtype: "h5") ?? [.fontSize: HeadingDefaultFontSize.h5.rawValue]
    }
  }

  // MARK: - Mutation

  override open func insertNewAfter(selection: RangeSelection?) throws -> Node? {
    let newElement = createParagraphNode()

    try newElement.setDirection(direction: getDirection())
    try insertAfter(nodeToInsert: newElement)

    return newElement
  }

  override public func collapseAtStart(selection: RangeSelection) throws -> Bool {
    let paragraph = createParagraphNode()

    try getChildren().forEach { node in
      try paragraph.append([node])
    }

    try replace(replaceWith: paragraph)

    return true
  }
}
