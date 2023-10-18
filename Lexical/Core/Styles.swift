/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

// MARK: - Style Swift types

public struct StyleName: Hashable, RawRepresentable {
  public init(rawValue: String) {
    self.rawValue = rawValue
  }
  public var rawValue: String
}

public enum StyleDisplayConstraint {
  case inline
  case block
  case none
}

public enum StyleContainerConstraint {
  case element
  case leaf
  case none
}

public protocol Style {
  static var name: StyleName { get }
  associatedtype StyleValueType: Codable

  // Constraints
  static var allowedNodes: [NodeType]? { get } // nil for allow any node type
  static var displayConstraint: StyleDisplayConstraint { get }
  static var containerConstraint: StyleContainerConstraint { get }

  // Rendering
  static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict
}

public extension Style {
  static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict {
    return theme.getStyleConvertedValue(self, value: value) ?? [:]
  }
}

public typealias StylesRegistrationDict = [StyleName : any Style.Type]
public typealias StylesDict = [StyleName : Codable]

// MARK: - Convenience place to put styles

public enum Styles {}

// MARK: - Editor API for registering styles

public extension Editor {
  func register<T: Style>(style: T.Type) {
    registeredStyles[style.name] = style
  }
}

// MARK: - Storage and manipulation of styles

public extension Node {
  func getStyle<T: Style>(_ style: T.Type) -> T.StyleValueType? {
    let styleVal = self.getLatest().styles[style.name]
    if let styleVal = styleVal as? T.StyleValueType {
      return styleVal
    }
    return nil
  }

  func setStyle<T: Style>(_ style: T.Type, _ value: T.StyleValueType?) throws {
    try validateStyleOrThrow(style)
    try getWritable().styles[style.name] = value
  }

  func getStyles() -> StylesDict {
    return getLatest().styles
  }

  func setStyles(_ stylesDict: StylesDict) throws {
    // TODO: validate all!
    try getWritable().styles = stylesDict
  }

  func toggleStyle<T: Style>(_ style: T.Type) throws where T.StyleValueType == Bool {
    let currentValue = getStyle(style) ?? false
    try setStyle(style, !currentValue)
  }

  func validateStyle<T: Style>(_ style: T.Type, value: T.StyleValueType?) -> T.StyleValueType? {
    do {
      try validateStyleOrThrow(style)
    } catch {
      return nil
    }
    return value
  }
}

internal extension Node {
  func validateStyleOrThrow<T: Style>(_ style: T.Type) throws {
    if let allowedNodes = style.allowedNodes, !allowedNodes.contains(self.type) {
      throw LexicalError.styleValidation("Node not in allowlist")
    }

    if style.containerConstraint == .element && !(self is ElementNode) {
      throw LexicalError.styleValidation("Style requires element node")
    }
    if style.containerConstraint == .leaf && self is ElementNode {
      throw LexicalError.styleValidation("Style requires leaf node")
    }

    if style.displayConstraint == .block {
      if let element = self as? ElementNode {
        if element.isInline() {
          throw LexicalError.styleValidation("Style requires block (aka not inline)")
        }
      } else {
        throw LexicalError.styleValidation("Style requires block, which must be element")
      }
    }

    if style.displayConstraint == .inline, let element = self as? ElementNode, !element.isInline() {
      throw LexicalError.styleValidation("Style requires inline")
    }

    if style.containerConstraint == .leaf && self is ElementNode {
      throw LexicalError.styleValidation("Style requires leaf node")
    }
  }
}

// MARK: - helpers

// This function exists to facilitate Swift's type conversion from some to any
internal func styleAttributesDictFor<T: Style>(node: Node, style: T.Type, theme: Theme) -> Theme.AttributeDict {
  guard let value = node.getStyle(style) else { return [:] }
  return style.attributes(for: value, theme: theme)
}

// MARK: - Commands

public typealias ApplyStyleCommandPayload<T: Style> = (T.Type, T.StyleValueType?)
public extension CommandType {
  static let applyTextStyle = CommandType(rawValue: "applyTextStyle")
  static let applyBlockStyle = CommandType(rawValue: "applyBlockStyle")
}

private typealias ApplyStyleCommandFirstUnpackPayload = (any Style.Type, Any?)
internal func registerStyleCommands(editor: Editor) {
  _ = editor.registerCommand(type: .applyTextStyle, listener: { payload in
    guard let firstUnpackPayload = payload as? ApplyStyleCommandFirstUnpackPayload else { return false }
    return processTextStylePayload(style: firstUnpackPayload.0, payload: firstUnpackPayload)
  })
}

// This function exists to facilitate Swift's type conversion from some to any
private func processTextStylePayload<T: Style>(style: T.Type, payload: ApplyStyleCommandFirstUnpackPayload) -> Bool {
  guard let payload = payload as? ApplyStyleCommandPayload<T>,
        let selection = try? getSelection()
    else { return false }

  let style = payload.0
  let value = payload.1

  do {
    try selection.applyTextStyle(style, value: value)
  } catch {
    return false
  }
  return true
}

// MARK: - Default styles

internal func registerDefaultStyles(editor: Editor) {
  editor.register(style: Styles.Bold.self)
}

extension StyleName {
  static let bold = StyleName(rawValue: "bold")
  static let italic = StyleName(rawValue: "italic")
  static let underline = StyleName(rawValue: "underline")
  static let strikethrough = StyleName(rawValue: "strikethrough")
  static let code = StyleName(rawValue: "code")
  static let superScript = StyleName(rawValue: "superScript")
  static let subScript = StyleName(rawValue: "subScript")
}

extension Styles {
  struct Bold: Style {
    typealias StyleValueType = Bool
    static var name: StyleName = .bold
    static var allowedNodes: [NodeType]? = nil
    static var displayConstraint: StyleDisplayConstraint = .inline
    static var containerConstraint: StyleContainerConstraint = .leaf
    static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict {
      return theme.getStyleConvertedValue(self, value: value) ?? [.bold : true]
    }
  }
  struct Italic: Style {
    typealias StyleValueType = Bool
    static var name: StyleName = .italic
    static var allowedNodes: [NodeType]? = nil
    static var displayConstraint: StyleDisplayConstraint = .inline
    static var containerConstraint: StyleContainerConstraint = .leaf
    static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict {
      return theme.getStyleConvertedValue(self, value: value) ?? [.italic : true]
    }
  }
  struct Underline: Style {
    typealias StyleValueType = Bool
    static var name: StyleName = .underline
    static var allowedNodes: [NodeType]? = nil
    static var displayConstraint: StyleDisplayConstraint = .inline
    static var containerConstraint: StyleContainerConstraint = .leaf
    static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict {
      return theme.getStyleConvertedValue(self, value: value) ?? [.underlineStyle : NSUnderlineStyle.single.rawValue]
    }
  }
  struct Strikethrough: Style {
    typealias StyleValueType = Bool
    static var name: StyleName = .strikethrough
    static var allowedNodes: [NodeType]? = nil
    static var displayConstraint: StyleDisplayConstraint = .inline
    static var containerConstraint: StyleContainerConstraint = .leaf
    static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict {
      return theme.getStyleConvertedValue(self, value: value) ?? [.strikethroughStyle : NSUnderlineStyle.single.rawValue]
    }
  }
  struct Code: Style {
    typealias StyleValueType = Bool
    static var name: StyleName = .code
    static var allowedNodes: [NodeType]? = nil
    static var displayConstraint: StyleDisplayConstraint = .inline
    static var containerConstraint: StyleContainerConstraint = .leaf
    static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict {
      return theme.getStyleConvertedValue(self, value: value) ?? [.fontFamily : "Courier", .backgroundColor : UIColor.lightGray]
    }
  }
  struct SuperScript: Style {
    typealias StyleValueType = Bool
    static var name: StyleName = .superScript
    static var allowedNodes: [NodeType]? = nil
    static var displayConstraint: StyleDisplayConstraint = .inline
    static var containerConstraint: StyleContainerConstraint = .leaf
    static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict {
      return theme.getStyleConvertedValue(self, value: value) ?? [:]
    }
  }
  struct SubScript: Style {
    typealias StyleValueType = Bool
    static var name: StyleName = .subScript
    static var allowedNodes: [NodeType]? = nil
    static var displayConstraint: StyleDisplayConstraint = .inline
    static var containerConstraint: StyleContainerConstraint = .leaf
    static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict {
      return theme.getStyleConvertedValue(self, value: value) ?? [:]
    }
  }
}


// MARK: - Compatibility with previous versions

public func compatibilityFormatFromStyles(_  stylesDict: StylesDict) -> TextFormat {

}

public func compatibilityStylesFromFormat(_ format: TextFormat) -> StylesDict {

}

public func compatibilityStyleFromFormatType(_ format: TextFormatType) -> some Style {

}

public func compatibilityMergeStylesAssumingAllFormats(old: StylesDict, newFormats: StylesDict) -> StylesDict {
  
}

// MARK: - JSON serialization

internal struct StyleCodingKeys: CodingKey {
  var stringValue: String
  var intValue: Int?
  init?(intValue: Int) {
    self.stringValue = "\(intValue)"
    self.intValue = intValue
  }
  init?(stringValue: String) { self.stringValue = stringValue }
}

internal func styleValueFromDecoder<T: Style>(_ style: T.Type, decoder: Decoder) throws -> T.StyleValueType? {
  return try style.StyleValueType.init(from: decoder)
}
