/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical
import UIKit

extension CommandType {
  public static let insertUnorderedList = CommandType(rawValue: "insertUnorderedList")
  public static let insertOrderedList = CommandType(rawValue: "insertOrderedList")
  public static let insertCheckList = CommandType(rawValue: "insertCheckList")
  public static let removeList = CommandType(rawValue: "removeList")
}

open class ListPlugin: Plugin {
  private var withPlaceholders: Bool

  public init(withPlaceholders: Bool = false) {
    self.withPlaceholders = withPlaceholders
  }

  weak var editor: Editor?

  public func setUp(editor: Editor) {
    self.editor = editor
    do {
      try editor.registerNode(nodeType: NodeType.list, class: ListNode.self)
      try editor.registerNode(nodeType: NodeType.listItem, class: ListItemNode.self)
      try editor.registerNode(nodeType: NodeType.listItemPlaceholder, class: ListItemPlaceholderNode.self)

      _ = editor.registerCommand(type: .insertUnorderedList, listener: { [weak editor] payload in
        guard let editor else { return false }
        try? insertList(editor: editor, listType: .bullet, withPlaceholders: self.withPlaceholders)
        return true
      })

      _ = editor.registerCommand(type: .insertOrderedList, listener: { [weak editor] payload in
        guard let editor else { return false }
        try? insertList(editor: editor, listType: .number, withPlaceholders: self.withPlaceholders)
        return true
      })

      _ = editor.registerCommand(type: .insertCheckList, listener: { [weak editor] payload in
        guard let editor else { return false }
        try? insertList(editor: editor, listType: .check, withPlaceholders: self.withPlaceholders)
        return true
      })

      try editor.registerCustomDrawing(customAttribute: .listItem, layer: .text, granularity: .contiguousParagraphs) {
        attributeKey, attributeValue, layoutManager, characterRange, expandedCharRange, glyphRange, rect, firstLineFragment in

        guard let attributeValue = attributeValue as? ListItemAttribute, let textStorage = layoutManager.textStorage as? TextStorage else {
          return
        }

        // we only want to do the drawing if we're the first character in a paragraph.
        // We could optimise this in the future by either (1) hooking in to TextKit string normalisation, or (2) subclassing
        // NSParagraphStyle
        if characterRange.location != 0 && (textStorage.string as NSString).substring(with: NSRange(location: characterRange.location - 1, length: 1)) != "\n" {
          return
        }

        let isFirstLine = (glyphRange.location == 0)

        var attributes = textStorage.attributes(at: characterRange.location, effectiveRange: nil)

        var spacingBefore = 0.0
        if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle, let mutableParagraphStyle = paragraphStyle.mutableCopy() as? NSMutableParagraphStyle {
          mutableParagraphStyle.headIndent = 0
          mutableParagraphStyle.firstLineHeadIndent = 0
          mutableParagraphStyle.tailIndent = 0
          spacingBefore = isFirstLine ? 0 : paragraphStyle.paragraphSpacingBefore
          mutableParagraphStyle.paragraphSpacingBefore = 0
          attributes[.paragraphStyle] = mutableParagraphStyle
        }
        attributes.removeValue(forKey: .underlineStyle)
        attributes.removeValue(forKey: .strikethroughStyle)
        let bulletDrawRect = firstLineFragment.inset(by: UIEdgeInsets(top: spacingBefore, left: attributeValue.characterIndentationPixels, bottom: 0, right: 0))

        if attributeValue.listType == .check {
          let configuration = UIImage.SymbolConfiguration(pointSize: bulletDrawRect.height, weight: .regular)
          let theme = editor.getTheme()

          let attributes: [NSAttributedString.Key : Any] = theme.listItem ?? [:]
          let checkedAtributes: [NSAttributedString.Key : Any] = theme.checkedListItem ?? [:]
          let uncheckedSymbolName = attributes[.checkSymbolName] as? String ?? "sqaure"
          let checkedSymbolName = checkedAtributes[.checkSymbolName] as? String ?? "checkmark.square.fill"

          let symbolName = attributeValue.isChecked ? checkedSymbolName : uncheckedSymbolName
          if let image = UIImage(systemName: symbolName, withConfiguration: configuration) {

            let checkForegroundColor = attributes[.checkForegroundColor] as? UIColor ?? UIColor.label
            let checkedCheckForegroundColor = checkedAtributes[.checkForegroundColor] as? UIColor ?? UIColor.label

            let textColor = attributeValue.isChecked ? checkedCheckForegroundColor : checkForegroundColor
            let tintedImage = image.withTintColor(textColor, renderingMode: .alwaysOriginal)

            let height = attributes[.checkRectHeight] as? CGFloat ?? bulletDrawRect.height
            let imageRect = CGRect(x: bulletDrawRect.minX, y: bulletDrawRect.minY, width: height, height: height)
            tintedImage.draw(in: imageRect)
          }
        } else {
          // For bullet and number lists, use the existing drawing method
          attributeValue.listItemCharacter.draw(in: bulletDrawRect, withAttributes: attributes)
        }

      }
    } catch {
      print("\(error)")
    }
  }

  public func tearDown() {
  }

  public func hitTest(at point: CGPoint, lineFragmentRect: CGRect, firstCharacterRect: CGRect, attributes: [NSAttributedString.Key : Any]) -> Bool {
    guard let listItemAttribute = attributes[.listItem] as? ListItemAttribute,
          listItemAttribute.listType == .check else {
      return false
    }

    let isWithinCheckboxRange = point.x < firstCharacterRect.minX
    return isWithinCheckboxRange
  }

  public func handleTap(at point: CGPoint, lineFragmentRect: CGRect, firstCharacterRect: CGRect, attributes: [NSAttributedString.Key : Any]) -> Bool {
    guard let listItemAttribute = attributes[.listItem] as? ListItemAttribute else {
      return false
    }

    var handled = false
    do {
      try editor?.update {
        guard let editorState = getActiveEditorState(),
              let node = editorState.getNodeMap()[listItemAttribute.itemNodeKey] as? ListItemNode else {
          return
        }

        let isChecked = node.getIsChecked()
        try node.setIsChecked(!isChecked)

        // TODO: make this configurable
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.prepare()
        impact.impactOccurred()
        handled = true
      }
    } catch {
      print("failed updating node: \(error)")
    }

    return handled
  }
}
