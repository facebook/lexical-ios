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

public protocol Style<StyleValueType> {
  static var name: StyleName { get }
  associatedtype StyleValueType: Codable & Equatable

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

public func stylesDictsAreEqual(_ dict1: StylesDict, _ dict2: StylesDict, editor: Editor) -> Bool {
  if dict1.keys != dict2.keys {
    return false
  }
  for key in dict1.keys {
    guard let style = editor.registeredStyles[key], let val1 = dict1[key], let val2 = dict2[key] else {
      return false
    }
    return stylesValuesAreEqual(val1, val2, style: style)
  }
  return true
}

private func stylesValuesAreEqual<T: Style>(_ val1: Any, _ val2: Any, style: T.Type) -> Bool {
  guard let val1 = val1 as? T.StyleValueType, let val2 = val2 as? T.StyleValueType else {
    return false
  }
  return val1 == val2
}

// MARK: - Convenience place to put styles

public enum Styles {}

// MARK: - Editor API for registering styles

public extension Editor {
  func register<T: Style>(style: T.Type) {
    registeredStyles[style.name] = style
  }
}

// MARK: - Storage and manipulation of styles

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
  editor.register(style: Styles.Italic.self)
  editor.register(style: Styles.Underline.self)
  editor.register(style: Styles.Strikethrough.self)
  editor.register(style: Styles.Code.self)
  editor.register(style: Styles.SuperScript.self)
  editor.register(style: Styles.SubScript.self)
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
      return theme.getStyleConvertedValue(self, value: value) ?? [.bold : value]
    }
  }
  struct Italic: Style {
    typealias StyleValueType = Bool
    static var name: StyleName = .italic
    static var allowedNodes: [NodeType]? = nil
    static var displayConstraint: StyleDisplayConstraint = .inline
    static var containerConstraint: StyleContainerConstraint = .leaf
    static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict {
      return theme.getStyleConvertedValue(self, value: value) ?? [.italic : value]
    }
  }
  struct Underline: Style {
    typealias StyleValueType = Bool
    static var name: StyleName = .underline
    static var allowedNodes: [NodeType]? = nil
    static var displayConstraint: StyleDisplayConstraint = .inline
    static var containerConstraint: StyleContainerConstraint = .leaf
    static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict {
      return theme.getStyleConvertedValue(self, value: value) ?? [.underlineStyle : value ? NSUnderlineStyle.single.rawValue : []]
    }
  }
  struct Strikethrough: Style {
    typealias StyleValueType = Bool
    static var name: StyleName = .strikethrough
    static var allowedNodes: [NodeType]? = nil
    static var displayConstraint: StyleDisplayConstraint = .inline
    static var containerConstraint: StyleContainerConstraint = .leaf
    static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict {
      return theme.getStyleConvertedValue(self, value: value) ?? [.strikethroughStyle : value ? NSUnderlineStyle.single.rawValue : []]
    }
  }
  struct Code: Style {
    typealias StyleValueType = Bool
    static var name: StyleName = .code
    static var allowedNodes: [NodeType]? = nil
    static var displayConstraint: StyleDisplayConstraint = .inline
    static var containerConstraint: StyleContainerConstraint = .leaf
    static func attributes(for value: StyleValueType, theme: Theme) -> Theme.AttributeDict {
      return theme.getStyleConvertedValue(self, value: value) ?? (value ? [.fontFamily : "Courier", .backgroundColor : UIColor.lightGray] : [:])
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
  var format = TextFormat()
  format.bold = (stylesDict[Styles.Bold.name] as? Bool) ?? false
  format.italic = (stylesDict[Styles.Italic.name] as? Bool) ?? false
  format.underline = (stylesDict[Styles.Underline.name] as? Bool) ?? false
  format.strikethrough = (stylesDict[Styles.Strikethrough.name] as? Bool) ?? false
  format.code = (stylesDict[Styles.Code.name] as? Bool) ?? false
  format.superScript = (stylesDict[Styles.SuperScript.name] as? Bool) ?? false
  format.subScript = (stylesDict[Styles.SubScript.name] as? Bool) ?? false
  return format
}

public func compatibilityStylesFromFormat(_ format: TextFormat) -> StylesDict {
  var styles: StylesDict = [:]
  if format.isTypeSet(type: .bold) {
    styles[Styles.Bold.name] = true
  }
  if format.isTypeSet(type: .italic) {
    styles[Styles.Italic.name] = true
  }
  if format.isTypeSet(type: .underline) {
    styles[Styles.Underline.name] = true
  }
  if format.isTypeSet(type: .strikethrough) {
    styles[Styles.Strikethrough.name] = true
  }
  if format.isTypeSet(type: .code) {
    styles[Styles.Code.name] = true
  }
  if format.isTypeSet(type: .superScript) {
    styles[Styles.SuperScript.name] = true
  }
  if format.isTypeSet(type: .subScript) {
    styles[Styles.SubScript.name] = true
  }
  return styles
}

public func compatibilityStyleFromFormatType(_ format: TextFormatType) -> any Style<Bool>.Type {
  switch format {
  case .bold:
    return Styles.Bold.self
  case .italic:
    return Styles.Italic.self
  case .underline:
    return Styles.Underline.self
  case .strikethrough:
    return Styles.Strikethrough.self
  case .code:
    return Styles.Code.self
  case .subScript:
    return Styles.SubScript.self
  case .superScript:
    return Styles.SuperScript.self
  }
}

public func compatibilityMergeStylesAssumingAllFormats(old: StylesDict, newFormats: StylesDict) -> StylesDict {
  var new = old
  new[Styles.Bold.name] = newFormats[Styles.Bold.name] ?? false
  new[Styles.Italic.name] = newFormats[Styles.Italic.name] ?? false
  new[Styles.Underline.name] = newFormats[Styles.Underline.name] ?? false
  new[Styles.Strikethrough.name] = newFormats[Styles.Strikethrough.name] ?? false
  new[Styles.Code.name] = newFormats[Styles.Code.name] ?? false
  new[Styles.SubScript.name] = newFormats[Styles.SubScript.name] ?? false
  new[Styles.SuperScript.name] = newFormats[Styles.SuperScript.name] ?? false
  return new
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
