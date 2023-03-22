// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation

extension NSAttributedString.Key {
  public static let fontFamily: NSAttributedString.Key = .init(rawValue: "fontFamily")
  public static let fontSize: NSAttributedString.Key = .init(rawValue: "fontSize")
  public static let bold: NSAttributedString.Key = .init(rawValue: "bold")
  public static let italic: NSAttributedString.Key = .init(rawValue: "italic")
  // uppercase or lowercase
  public static let textTransform: NSAttributedString.Key = .init(rawValue: "textTransform")
  public static let paddingHead: NSAttributedString.Key = .init(rawValue: "paddingHead")
  public static let paddingTail: NSAttributedString.Key = .init(rawValue: "paddingTail")
  public static let lineHeight: NSAttributedString.Key = .init(rawValue: "lineHeight")
  public static let lineSpacing: NSAttributedString.Key = .init(rawValue: "lineSpacing")
  public static let paragraphSpacingBefore: NSAttributedString.Key = .init(rawValue: "paragraphSpacingBefore")
}
