/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import UIKit

public enum TextNodeThemeSubtype {
  public static let code = "code"
}

extension TextFormatType {
  func makeAttributedStringKey(with theme: Theme) -> [NSAttributedString.Key: Any] {
    switch self {
    case .bold: return [.bold: true]
    case .italic: return [.italic: true]
    case .underline: return [.underlineStyle: NSUnderlineStyle.single.rawValue]
    case .strikethrough: return [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
    case .code:
      if let themeDict = theme.getValue(.text, withSubtype: TextNodeThemeSubtype.code) {
        return themeDict
      } else {
        return [
          .fontFamily: "Courier",
          .backgroundColor: UIColor.lightGray
        ]
      }
    default:
      return [:]
    }
  }
}

struct SerializedTextNodeDetail: OptionSet, Codable {
  public let rawValue: Int

  public static let isDirectionless = SerializedTextNodeDetail(rawValue: 1 << 0)
  public static let isUnmergeable = SerializedTextNodeDetail(rawValue: 1 << 1)

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  // On encode, convert from TextNodeDetail -> SerializedTextNodeDetail
  public static func convertToSerializedTextNodeDetail(from textDetail: TextNodeDetail) -> SerializedTextNodeDetail {
    var serialTextDetail = SerializedTextNodeDetail()
    if textDetail.isDirectionless {
      serialTextDetail.insert(.isDirectionless)
    }
    if textDetail.isUnmergable {
      serialTextDetail.insert(.isUnmergeable)
    }
    return serialTextDetail
  }

  // On decode, convert from SerializedTextNodeDetail -> TextNodeDetail
  public static func convertToTextDetail(from serialTextDetail: SerializedTextNodeDetail) -> TextNodeDetail {
    var textDetail = TextNodeDetail()
    if serialTextDetail.contains(.isDirectionless) {
      textDetail.isDirectionless = true
    }
    if serialTextDetail.contains(.isUnmergeable) {
      textDetail.isUnmergable = true
    }

    return textDetail
  }
}

struct TextNodeDetail: Codable {
  var isDirectionless: Bool = false
  var isUnmergable: Bool = false
}

open class TextNode: Node {
  enum CodingKeys: String, CodingKey {
    case text
    case mode
    case format
    case detail
    case style
  }

  private var text: String = ""
  public var mode: Mode = .normal
  var format = TextFormatType()
  var detail = TextNodeDetail()
  var style: String = ""

  override public init() {
    super.init()
  }

  public required init(text: String, key: NodeKey?) {
    super.init(key)
    self.text = text
  }

  override open class func getType() -> NodeType {
    return .text
  }

  public convenience init(text: String) {
    self.init(text: text, key: LexicalConstants.uninitializedNodeKey)
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try super.init(from: decoder)

    self.text = try container.decode(String.self, forKey: .text)
    self.mode = try container.decode(Mode.self, forKey: .mode)
    self.format = try container.decode(TextFormatType.self, forKey: .format)
    let serializedDetail = try container.decode(SerializedTextNodeDetail.self, forKey: .detail)
    self.detail = SerializedTextNodeDetail.convertToTextDetail(from: serializedDetail)
    self.style = try container.decode(String.self, forKey: .style)
  }

  override open func encode(to encoder: Encoder) throws {
    try super.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.text, forKey: .text)
    try container.encode(self.mode, forKey: .mode)
    try container.encode(self.format, forKey: .format)
    try container.encode(SerializedTextNodeDetail.convertToSerializedTextNodeDetail(from: self.detail).rawValue, forKey: .detail)
    try container.encode(self.style, forKey: .style)
  }

  override public func getTextPart() -> String {
    return getLatest().text
  }

  public func setText(_ text: String) throws {
    try errorOnReadOnly()
    try getWritable().text = text
  }

  public func setText_dangerousPropertyAccess(_ text: String) {
    self.text = text
  }

  public func getText_dangerousPropertyAccess() -> String {
    return self.text
  }

  public func getMode_dangerousPropertyAccess() -> Mode {
    return self.mode
  }

  public func setBold(_ isBold: Bool) throws {
    try errorOnReadOnly()
    try getWritable().format.toggle(.bold)
  }

  public func setItalic(_ isItalic: Bool) throws {
    try errorOnReadOnly()
    try getWritable().format.toggle(.italic)
  }

  public func canInsertTextAfter() -> Bool {
    return true
  }

  override open func clone() -> Self {
    return Self(text: text, key: key)
  }

  override open func getAttributedStringAttributes(theme: Theme) -> [NSAttributedString.Key: Any] {
    let attributeDictionary = super.getAttributedStringAttributes(theme: theme)

    // TODO: Remove this once codeHighlight node is implemented
    if let parent, let _ = getNodeByKey(key: parent) as? CodeNode {
      format = TextFormatType()
    }

    return attributeDictionary.merging(
      TextFormatType
        .allCases
        .filter {
          format.contains($0)
        }
        .reduce([:]) { partialResult, type in
          return partialResult.merging(type.makeAttributedStringKey(with: theme)) { _, new in new }
        }, 
      uniquingKeysWith: { _, new in
        return new
      })
  }

  public func isInert() -> Bool {
    let node = getLatest() as TextNode
    return node.mode == .inert
  }

  public func isToken() -> Bool {
    let node = getLatest() as TextNode
    return node.mode == .token
  }

  public func isComposing() -> Bool {
    return key == getCompositionKey()
  }

  public func spliceText(
    offset: Int,
    delCount: Int,
    newText: String,
    moveSelection: Bool = false
  ) throws -> TextNode {
    try errorOnReadOnly()
    let writableNode = try getWritable() as TextNode
    let text = writableNode.getTextPart()
    var index = offset

    if index < 0 {
      index = newText.lengthAsNSString() + index
      if index < 0 {
        index = 0
      }
    }

    let convertedText = text as NSString
    let prefixText = convertedText.substring(
      with: NSRange(
        location: 0,
        length: index
      )
    )

    // In JS, slice will continue to function even if there are bad boundary conditions. Here,
    // we clamp with substring to permit a similar resilience to maintain parity with web code.
    let postText = convertedText.substring(
      with: NSRange(
        location: max(min(index + delCount, convertedText.length), 0),
        length: max(min(convertedText.length - (index + delCount), convertedText.length), 0)
      )
    )

    try writableNode.setText("\(prefixText)\(newText)\(postText)")

    let selection = try getSelection(allowInvalidPositions: true)
    if moveSelection, let selection = selection as? RangeSelection {
      let newOffset = offset + newText.lengthAsNSString()
      selection.setTextNodeRange(
        anchorNode: writableNode,
        anchorOffset: newOffset,
        focusNode: writableNode,
        focusOffset: newOffset
      )
    }

    return writableNode
  }

  public func isSegmented() -> Bool {
    let node = getLatest() as TextNode
    return node.mode == .segmented
  }

  @discardableResult
  public func setMode(mode: Mode) throws -> TextNode {
    try errorOnReadOnly()
    let node = try getWritable() as TextNode
    node.mode = mode
    return getLatest()
  }

  func canInsertTextBefore() -> Bool {
    return true
  }

  public func getFormat() -> TextFormatType {
    let node = getLatest() as TextNode
    return node.format
  }

  @discardableResult
  public func setFormat(format: TextFormatType) throws -> TextNode {
    try errorOnReadOnly()
    let node = try getWritable() as TextNode
    node.format = format
    return node
  }

  public func getStyle() -> String {
    let node = getLatest() as TextNode
    return node.style
  }

  public func setStyle(_ style: String) throws {
    let writable = try getWritable()
    writable.style = style
  }

  public func splitText(splitOffsets: [Int]) throws -> [TextNode] {
    try errorOnReadOnly()
    let textContent = getTextPart() as NSString
    let textLength = textContent.length
    let offsetsSet = Set(splitOffsets)
    var parts = [String]()
    var string: NSMutableString = NSMutableString(string: "")

    for i in 0..<textLength {
      if string != "" && offsetsSet.contains(i) {
        parts.append(string as String)
        string = NSMutableString(string: "")
      }
      string.append(textContent.substring(with: NSRange(location: i, length: 1)))
    }
    if string != "" {
      parts.append(string as String)
    }
    let partsLength = parts.count
    if partsLength == 0 {
      return []
    } else if parts[0] == textContent as String {
      return [getLatest()]
    }
    let firstPart = parts[0]
    guard let parent = getParent() else {
      return []
    }
    let parentKey = parent.key
    var writableNode = TextNode()
    let format = getFormat()
    let style = getStyle()
    let detail = detail
    var hasReplacedSelf = false

    if isSegmented() {
      // Create a new TextNode
      writableNode = createTextNode(text: firstPart)
      writableNode.parent = parentKey
      writableNode.format = format
      writableNode.style = style
      writableNode.detail = detail
      hasReplacedSelf = true
    } else {
      // For the first part, update the existing node
      writableNode = try getWritable()
      writableNode.text = firstPart
    }
    // Handle selection
    let selection = try getSelection()

    // Then handle all other parts
    var splitNodes = [writableNode]
    var textSize = firstPart.lengthAsNSString()
    for i in 1..<partsLength {
      let part = parts[i]
      let partSize = part.lengthAsNSString()
      let sibling = try createTextNode(text: part).getWritable()
      sibling.format = format
      sibling.style = style
      sibling.detail = detail
      let siblingKey = sibling.key
      let nextTextSize = textSize + partSize

      if let selection = selection as? RangeSelection {
        let anchor = selection.anchor
        let focus = selection.focus

        if anchor.key == key &&
            anchor.type == .text &&
            anchor.offset > textSize &&
            anchor.offset <= nextTextSize {
          anchor.key = siblingKey
          anchor.offset -= textSize
          selection.dirty = true
        }

        if focus.key == key &&
            focus.type == .text &&
            focus.offset > textSize &&
            focus.offset <= nextTextSize {
          focus.key = siblingKey
          focus.offset -= textSize
          selection.dirty = true
        }
      }

      textSize = nextTextSize
      sibling.parent = parentKey
      splitNodes.append(sibling)
    }
    // Insert the nodes into the parent's children
    internallyMarkNodeAsDirty(node: self, cause: .userInitiated)
    let writableParent = try parent.getWritable() as ElementNode
    guard let insertionIndex = writableParent.children.firstIndex(of: key) else { return [] }

    let splitNodesKeys = splitNodes.map({ splitNode in
      splitNode.key
    })

    if hasReplacedSelf {
      writableParent.children.insert(contentsOf: splitNodesKeys, at: insertionIndex)
      try remove()
    } else {
      writableParent.children.replaceSubrange(insertionIndex...insertionIndex, with: splitNodesKeys)
    }

    if let selection = selection as? RangeSelection {
      try updateElementSelectionOnCreateDeleteNode(
        selection: selection,
        parentNode: parent,
        nodeOffset: insertionIndex,
        times: partsLength - 1)
    }
    return splitNodes
  }

  public func isSimpleText() -> Bool {
    return type == NodeType.text && mode == .normal
  }

  @discardableResult
  public func select(anchorOffset: Int?, focusOffset: Int?) throws -> RangeSelection {
    try errorOnReadOnly()
    let selection = try getSelection()
    let text = getTextPart()

    let lastOffset = text.lengthAsNSString()
    var updatedAnchorOffset = lastOffset
    var updatedFocusOffset = lastOffset
    if let anchorOffset {
      updatedAnchorOffset = anchorOffset
    }
    if let focusOffset {
      updatedFocusOffset = focusOffset
    }

    guard let selection else {
      return try makeRangeSelection(
        anchorKey: key,
        anchorOffset: updatedAnchorOffset,
        focusKey: key,
        focusOffset: updatedFocusOffset,
        anchorType: .text,
        focusType: .text)
    }
    guard let selection = selection as? RangeSelection else {
      return try makeRangeSelection(anchorKey: key, 
                                    anchorOffset: updatedAnchorOffset,
                                    focusKey: key,
                                    focusOffset: updatedAnchorOffset,
                                    anchorType: .text,
                                    focusType: .text)
    }

    selection.setTextNodeRange(anchorNode: self, 
                               anchorOffset: updatedAnchorOffset,
                               focusNode: self, 
                               focusOffset: updatedFocusOffset)

    return selection
  }

  public func getFormatFlags(type: TextFormatType,
                             alignWithFormat: TextFormatType? = nil) -> TextFormatType {
    let node = getLatest() as TextNode
    let format = node.format
    return toggleTextFormatType(format: format, type: type, alignWithFormat: alignWithFormat)
  }

  public func mergeWithSibling(target: TextNode) throws -> TextNode {
    var isBefore: Bool
    isBefore = target == getPreviousSibling()

    if !isBefore && target != getNextSibling() {
      throw LexicalError.internal("mergeWithSibling: sibling must be a previous or next sibling")
    }

    let targetKey = target.key
    let textLength = text.lengthAsNSString()
    let selection = try getSelection()
    if let selection = selection as? RangeSelection {
      let anchor = selection.anchor
      let focus = selection.focus

      for point in [anchor, focus] {
        if point.key == targetKey {
          // The Point was inside the now removed node
          adjustPointOffsetForMergedSibling(point: point,
                                            isBefore: isBefore,
                                            key: key,
                                            target: target,
                                            textLength: textLength)
          selection.dirty = true
        } else if point.key == self.key && point.type == .text && isBefore {
          // The Point is in self, and it's type text, and we're being merged with a previous sibling.
          // So we need to adjust the point's offset to accommodate.
          point.offset += target.getTextPartSize()
          selection.dirty = true
        }
      }
    }
    let newText = isBefore ? target.text + text : text + target.text
    try setText(newText)
    try target.remove()
    return getLatest()
  }

  override public func getTextContent(
    includeInert: Bool = false,
    includeDirectionless: Bool = false
  ) -> String {
    if (!includeInert && isInert()) || (!includeDirectionless && isDirectionless()) {
      return ""
    }

    let node = getLatest() as TextNode
    return node.getTextPart()
  }

  @discardableResult
  public func toggleDirectionless() throws -> TextNode {
    try errorOnReadOnly()
    let node = try getWritable() as TextNode
    node.detail.isDirectionless = !node.detail.isDirectionless
    return getLatest()
  }

  func isDirectionless() -> Bool {
    let node = getLatest() as TextNode
    return node.detail.isDirectionless
  }

  func isUnmergeable() -> Bool {
    let node = getLatest() as TextNode
    return node.detail.isUnmergable
  }

  static func canSimpleTextNodesBeMerged(node1: TextNode, node2: TextNode) -> Bool {
    let node1Mode = node1.mode
    let node1Format = node1.format
    let node1Style = node1.style
    let node2Mode = node2.mode
    let node2Format = node2.format
    let node2Style = node2.style

    return node1Mode == node2Mode &&
      node1Format == node2Format &&
      node1Style == node2Style
  }

  static func mergeTextNodes(node1: TextNode, node2: TextNode) throws -> TextNode {
    let writableNode1 = try node1.mergeWithSibling(target: node2)
    guard let editor = getActiveEditor() else {
      throw LexicalError.invariantViolation("Cannot be called outside update loop")
    }
    var normalizedNodes = editor.normalizedNodes
    normalizedNodes.insert(node1.key)
    normalizedNodes.insert(node2.key)
    return writableNode1
  }

  static func normalizeTextNode(textNode: TextNode) throws {
    var node = textNode
    if node.text == "" && node.isSimpleText() && !node.isUnmergeable() {
      try node.remove()
      return
    }
    // Backward
    while let previousNode = node.getPreviousSibling() {
      guard let textNode = previousNode as? TextNode, textNode.isSimpleText(), !textNode.isUnmergeable() else { break }

      if textNode.text == "" {
        try textNode.remove()
      } else if canSimpleTextNodesBeMerged(node1: textNode, node2: node) {
        node = try mergeTextNodes(node1: textNode, node2: node)
        break
      } else {
        break
      }
    }
    // Forward
    while let nextNode = node.getNextSibling() {
      guard let textNode = nextNode as? TextNode, textNode.isSimpleText(), !textNode.isUnmergeable() else { break }

      if textNode.text == "" {
        try textNode.remove()
      } else if canSimpleTextNodesBeMerged(node1: node, node2: textNode) {
        node = try mergeTextNodes(node1: node, node2: textNode)
        break
      } else {
        break
      }
    }
  }

  public static func ==(lhs: TextNode, rhs: TextNode) -> Bool {
    return (lhs.getTextPart() == rhs.getTextPart()) && (lhs.key == rhs.key)
  }
}

extension TextNode: CustomDebugStringConvertible {
  public var debugDescription: String {
    return "TextNode: \"\(text)\""
  }
}

extension TextFormatType: CustomDebugStringConvertible {
  public var debugDescription: String {
    TextFormatType.allCases.compactMap {
      return self.contains($0) ? $0.description : nil
    }
    .joined(separator: ", ")
  }
}

public extension NSAttributedString.Key {
  static let inlineCodeBackgroundColor: NSAttributedString.Key = .init(rawValue: "inlineCodeBackgroundColor")
}

extension TextNode {
  internal static var inlineCodeBackgroundDrawing: CustomDrawingHandler {
    get {
      return { attributeKey, attributeValue, layoutManager, attributeRunCharacterRange, granularityExpandedCharacterRange, glyphRange, rect, firstLineFragment in
        guard let attributeValue = attributeValue as? UIColor else { return }
        attributeValue.setFill()
        UIRectFill(rect)
      }
    }
  }
}
