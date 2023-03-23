/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import Foundation
import UIKit

public class RangeSelection: BaseSelection {

  public var anchor: Point
  public var focus: Point
  public var dirty: Bool
  public var format: TextFormat

  // MARK: - Init

  public init(anchor: Point, focus: Point, format: TextFormat) {
    self.anchor = anchor
    self.focus = focus
    self.dirty = false
    self.format = format
  }

  // MARK: - Public

  public func isBackward() throws -> Bool {
    return try focus.isBefore(point: anchor)
  }

  public func isCollapsed() -> Bool {
    return anchor == focus
  }

  public func hasFormat(type: TextFormatType) -> Bool {
    return format.isTypeSet(type: type)
  }

  public func getCharacterOffsets(selection: RangeSelection) -> (Int, Int) {
    let anchor = selection.anchor
    let focus = selection.focus
    if anchor.type == .element && focus.type == .element &&
        anchor.key == focus.key && anchor.offset == focus.offset {
      return (0, 0)
    }
    return (anchor.getCharacterOffset(), focus.getCharacterOffset())
  }

  public func getNodes() throws -> [Node] {
    var firstNode = try anchor.getNode()
    var lastNode = try focus.getNode()

    if let elementNode = firstNode as? ElementNode {
      firstNode = elementNode.getDescendantByIndex(index: anchor.offset)
    }
    if let elementNode = lastNode as? ElementNode {
      lastNode = elementNode.getDescendantByIndex(index: focus.offset)
    }
    if firstNode == lastNode {
      if isElementNode(node: firstNode) {
        return []
      }
      return [firstNode]
    }
    return firstNode.getNodesBetween(targetNode: lastNode)
  }

  public func clone() -> BaseSelection {
    let selectionAnchor = createPoint(key: anchor.key,
                                      offset: anchor.offset,
                                      type: anchor.type)
    let selectionFocus = createPoint(key: focus.key,
                                     offset: focus.offset,
                                     type: focus.type)
    return RangeSelection(anchor: selectionAnchor, focus: selectionFocus, format: format)
  }

  public func setTextNodeRange(anchorNode: TextNode,
                               anchorOffset: Int,
                               focusNode: TextNode,
                               focusOffset: Int) {
    anchor.updatePoint(key: anchorNode.key, offset: anchorOffset, type: .text)
    focus.updatePoint(key: focusNode.key, offset: focusOffset, type: .text)
    dirty = true
  }

  public func extract() throws -> [Node] {
    var selectedNodes = try getNodes()
    guard let firstNode = selectedNodes.first else { return [] }

    let lastNode = selectedNodes.last
    let anchorOffset = anchor.getCharacterOffset()
    let focusOffset = focus.getCharacterOffset()

    if selectedNodes.isEmpty {
      return []
    } else if selectedNodes.count == 1 {
      guard let firstNode = firstNode as? TextNode else { return [firstNode] }

      let startOffset = anchorOffset > focusOffset ? focusOffset : anchorOffset
      let endOffset = anchorOffset > focusOffset ? anchorOffset : focusOffset
      let splitNodes = try firstNode.splitText(splitOffsets: [startOffset, endOffset])
      guard let node = startOffset == 0 ? splitNodes.first : splitNodes[1] else { return [] }
      return [node]
    }

    let isBefore = try anchor.isBefore(point: focus)

    if let firstNode = firstNode as? TextNode {
      let startOffset = isBefore ? anchorOffset : focusOffset
      if startOffset == firstNode.getTextContentSize() {
        selectedNodes.removeFirst()
      } else if startOffset != 0 {
        let splitNodes = try firstNode.splitText(splitOffsets: [startOffset])
        selectedNodes[0] = splitNodes[0]
      }
    }

    if let lastNode = lastNode as? TextNode {
      let lastNodeText = lastNode.getTextContent()
      let endOffset = isBefore ? focusOffset : anchorOffset

      if endOffset == 0 {
        selectedNodes.removeLast()
      } else if endOffset != lastNodeText.lengthAsNSString() {
        let splitNodes = try lastNode.splitText(splitOffsets: [endOffset])
        selectedNodes.append(splitNodes[0])
      }
    }

    return selectedNodes
  }

  public func insertRawText(text: String) throws {
    let parts = text.split { $0 == "\n" || $0 == "\r\n" }.map(String.init)
    if parts.count == 1 {
      try insertText(text)
    } else {
      var nodes = [Node]()
      let length = parts.count
      for (index, _) in parts.enumerated() {
        let part = parts[index]
        if !part.isEmpty {
          nodes.append(createTextNode(text: part))
        }
        if index != length - 1 {
          nodes.append(createLineBreakNode())
        }
      }
      _ = try insertNodes(nodes: nodes, selectStart: false)
    }
  }

  public func getTextContent() throws -> String {
    let nodes = try getNodes()
    if nodes.count == 0 {
      return ""
    }
    let firstNode = nodes[0]
    let lastNode = nodes[nodes.count - 1]
    let isBefore = try anchor.isBefore(point: focus)
    let anchorOffset = anchor.getCharacterOffset()
    let focusOffset = focus.getCharacterOffset()
    var textContent = ""
    var prevWasElement = true
    var textSliceAnchor = String()
    var textSliceFocus = String()

    for node in nodes {
      if let elementNode = node as? ElementNode, !elementNode.isInline() {
        if !prevWasElement {
          textContent += "\n"
        }
        if elementNode.isEmpty() {
          prevWasElement = false
        } else {
          prevWasElement = true
        }
      } else {
        prevWasElement = false
        if isTextNode(node) {
          var text = node.getTextContent()

          if node == firstNode {
            if node == lastNode {
              if anchorOffset < focusOffset {
                let anchorRange = NSRange(location: anchorOffset, length: focusOffset - anchorOffset)
                textSliceAnchor = (text as NSString).substring(with: anchorRange)
              } else {
                let focusRange = NSRange(location: focusOffset, length: anchorOffset - focusOffset)
                textSliceFocus = (text as NSString).substring(with: focusRange)
              }

              text = anchorOffset < focusOffset ? textSliceAnchor : textSliceFocus
            } else {
              if isBefore {
                textSliceAnchor = (text as NSString).substring(from: anchorOffset)
              } else {
                textSliceFocus = (text as NSString).substring(from: focusOffset)
              }

              text = isBefore ? textSliceAnchor : textSliceFocus
            }
          } else if node == lastNode {
            if isBefore {
              textSliceAnchor = (text as NSString).substring(to: focusOffset)
            } else {
              textSliceFocus = (text as NSString).substring(to: anchorOffset)
            }

            text = isBefore ? textSliceAnchor : textSliceFocus
          }

          textContent += text
        } else if (isDecoratorNode(node) || isLineBreakNode(node)) && (node != lastNode || !isCollapsed()) {
          textContent += node.getTextContent()
        }
      }
    }

    return textContent
  }

  public func insertText(_ text: String) throws {
    let anchor = anchor
    let focus = focus
    let isBefore = try isCollapsed() || anchor.isBefore(point: focus)

    if isBefore && anchor.type == .element {
      try transferStartingElementPointToTextPoint(start: anchor, end: focus, format: format)
    } else if !isBefore && focus.type == .element {
      try transferStartingElementPointToTextPoint(start: focus, end: anchor, format: format)
    }

    let selectedNodes = try getNodes()
    let selectedNodesLength = selectedNodes.count
    let firstPoint = isBefore ? anchor : focus
    let endPoint = isBefore ? focus : anchor
    let startOffset = firstPoint.offset
    let endOffset = endPoint.offset

    guard var firstNode = selectedNodes[0] as? TextNode else {
      throw LexicalError.invariantViolation("insertText: first node is not a text node")
    }

    let firstNodeText = firstNode.getTextPart()
    let firstNodeTextLength = firstNodeText.lengthAsNSString()
    let firstNodeParent = try firstNode.getParentOrThrow()

    if isCollapsed() && startOffset == firstNodeTextLength &&
        (firstNode.isSegmented() || firstNode.isToken() || !firstNode.canInsertTextAfter() || !firstNodeParent.canInsertTextAfter()) {
      var nextSibling = firstNode.getNextSibling() as? TextNode
      if !isTextNode(nextSibling) || isTokenOrInertOrSegmented(nextSibling) {
        nextSibling = createTextNode(text: "")
        guard let nextSibling = nextSibling else {
          return
        }
        if !firstNodeParent.canInsertTextAfter() {
          _ = try firstNodeParent.insertAfter(nodeToInsert: nextSibling)
        } else {
          _ = try firstNode.insertAfter(nodeToInsert: nextSibling)
        }
      }
      guard let nextSibling = nextSibling else {
        return
      }
      _ = try nextSibling.select(anchorOffset: 0, focusOffset: 0)
      firstNode = nextSibling
      if text != "" {
        try insertText(text)
        return
      }
    } else if isCollapsed() && startOffset == 0 &&
                (firstNode.isSegmented() || firstNode.isToken() || !firstNode.canInsertTextBefore() || !firstNodeParent.canInsertTextBefore()) {
      var prevSibling = firstNode.getPreviousSibling() as? TextNode
      if !isTextNode(prevSibling ) || isTokenOrInertOrSegmented(prevSibling) {
        prevSibling = createTextNode(text: "")
        guard let prevSibling = prevSibling else {
          return
        }
        if !firstNodeParent.canInsertTextBefore() {
          _ = try firstNodeParent.insertBefore(nodeToInsert: prevSibling)
        } else {
          _ = try firstNode.insertBefore(nodeToInsert: prevSibling)
        }
      }
      guard let prevSibling = prevSibling else {
        return
      }
      _ = try prevSibling.select(anchorOffset: nil, focusOffset: nil)
      firstNode = prevSibling
      if text != "" {
        try insertText(text)
        return
      }
    } else if firstNode.isSegmented() && startOffset != firstNodeTextLength {
      let textNode = createTextNode(text: firstNode.getTextContent(includeInert: false, includeDirectionless: true))
      _ = try firstNode.replace(replaceWith: textNode)
      firstNode = textNode
    }

    if selectedNodesLength == 1 {
      if isTokenOrInert(firstNode) {
        try firstNode.remove()
        return
      }
      let firstNodeFormat = firstNode.getFormat()

      if startOffset == endOffset && firstNodeFormat != format {
        if firstNode.getTextPart().isEmpty {
          firstNode = try firstNode.setFormat(format: format)
        } else {
          var textNode = createTextNode(text: text)
          textNode = try textNode.setFormat(format: format)
          _ = try textNode.select(anchorOffset: nil, focusOffset: nil)
          if startOffset == 0 {
            _ = try firstNode.insertBefore(nodeToInsert: textNode)
          } else {
            let targetNodeArray = try firstNode.splitText(splitOffsets: [startOffset])
            guard let targetNode = targetNodeArray.first else {
              throw LexicalError.invariantViolation("insertText: splitText returned no node")
            }
            try targetNode.insertAfter(nodeToInsert: textNode)
          }
          return
        }
      }
      let delCount = endOffset - startOffset

      firstNode = try firstNode.spliceText(offset: startOffset, delCount: delCount, newText: text, moveSelection: true)

      if firstNode.getTextPart().isEmpty {
        try firstNode.remove()
      } else if firstNode.isComposing() && anchor.type == .text {
        anchor.offset -= text.lengthAsNSString()
      }
    } else {
      let lastIndex = selectedNodesLength - 1
      var lastNode = selectedNodes[lastIndex]
      var markedNodeKeysForKeep: Set<String> = Set(firstNode.getParentKeys())
      lastNode.getParentKeys().forEach({ markedNodeKeysForKeep.insert($0) })

      // First node is a TextNode, so we're getting a new "firstNode" from the start of selectedNodes
      let firstElement: ElementNode
      if let elementNode = selectedNodes[0] as? ElementNode {
        firstElement = elementNode
      } else {
        firstElement = try firstNode.getParentOrThrow()
      }

      let lastElement: ElementNode = try (lastNode as? ElementNode ?? lastNode.getParentOrThrow())

      // Handle mutations to the last node.
      if let lastIndex = lastNode.getIndexWithinParent() {
        if endPoint.type == .text && (endOffset != 0 || lastNode.getTextPart().isEmpty) ||
            (endPoint.type == .element && lastIndex < endOffset) {
          if let lastTextNode = lastNode as? TextNode,
             !isTokenOrInert(lastTextNode) && endOffset != lastTextNode.getTextContentSize() {
            if lastTextNode.isSegmented() {
              let textNode = createTextNode(text: lastNode.getTextContent())
              _ = try lastNode.replace(replaceWith: textNode)
              lastNode = textNode
            }
            lastNode = try lastTextNode.spliceText(offset: 0, delCount: endOffset, newText: "")
            markedNodeKeysForKeep.insert(lastNode.getKey())
          } else {
            if format != firstNode.format, let lastTextNode = lastNode as? TextNode {
              lastNode = try lastTextNode.spliceText(offset: 0, delCount: endOffset, newText: text, moveSelection: true)
              markedNodeKeysForKeep.insert(lastNode.getKey())
            } else {
              try lastNode.remove()
            }
          }
        } else {
          markedNodeKeysForKeep.insert(lastNode.getKey())
        }
      }

      // Either move the remaining nodes of the last parent to after
      // the first child, or remove them entirely. If the last parent
      // is the same as the first parent, this logic also works.
      let lastNodeChildren = lastElement.getChildren().reversed()
      let selectedNodesSet = Set(selectedNodes)
      let firstAndLastElementsAreEqual = firstElement === lastElement

      // If the last element is an "inline" element, don't move it's text nodes to the first node.
      // Instead, preserve the "inline" element's children and append to the first element.
      if !lastElement.canBeEmpty() {
        try firstElement.append([lastElement])
      } else {
        for node in lastNodeChildren {
          if node === firstNode {
            break
          }

          if node.isAttached() {
            if !selectedNodesSet.contains(node) || node === lastNode {
              if !firstAndLastElementsAreEqual {
                _ = try firstNode.insertAfter(nodeToInsert: node)
              }
            } else {
              try node.remove()
            }
          }
        }

        if !firstAndLastElementsAreEqual {
          // Check if we have already moved out all the nodes of the
          // last parent, and if so, traverse the parent tree and mark
          // them all as being able to deleted too.
          var parent: Node? = lastElement
          var lastRemovedParent: Node?

          while let unwrappedParent = parent as? ElementNode {
            let children = unwrappedParent.getChildren()
            let childrenLength = children.count

            if childrenLength == 0 || children[childrenLength - 1].isSameKey(lastRemovedParent) {
              markedNodeKeysForKeep.remove(unwrappedParent.getKey())
              lastRemovedParent = unwrappedParent
            }

            parent = unwrappedParent.getParent()
          }
        }
      }

      if firstNode.format == format {
        // Ensure we do splicing after moving of nodes, as splicing
        // can have side-effects (in the case of hashtags).
        if !isTokenOrInert(firstNode) {
          firstNode = try firstNode.spliceText(
            offset: startOffset,
            delCount: firstNodeTextLength - startOffset,
            newText: text,
            moveSelection: true
          )
          if firstNode.getTextPart().isEmpty {
            try firstNode.remove()
          } else if firstNode.isComposing() && anchor.type == .text {
            anchor.offset -= text.lengthAsNSString()
          }
        } else if startOffset == firstNodeTextLength {
          _ = try firstNode.select(anchorOffset: nil, focusOffset: nil)
        } else {
          try firstNode.remove()
        }
      }

      // Remove all selected nodes that haven't already been removed.
      for node in selectedNodes[1..<selectedNodes.count] {
        let key = node.getKey()

        if !markedNodeKeysForKeep.contains(key) &&
            (!isElementNode(node: node) || ((node as? ElementNode)?.canSelectionRemove() ?? false)) {
          try node.remove()
        }
      }
    }
  }

  public func insertNodes(nodes: [Node], selectStart: Bool) throws -> Bool {
    if !isCollapsed() {
      try removeText()
    }

    let anchor = anchor
    let anchorOffset = anchor.offset
    let anchorNode = try anchor.getNode()
    var target = anchorNode

    if anchor.type == .element {
      if let element = try anchor.getNode() as? ElementNode {
        if let placementNode = element.getChildAtIndex(index: anchorOffset - 1) {
          target = placementNode
        } else {
          target = element
        }
      }
    }

    var siblings: [Node] = []

    let nextSiblings = anchorNode.getNextSiblings()
    let topLevelElement = anchorNode.getTopLevelElementOrThrow()

    if let anchorNode = anchorNode as? TextNode {
      let textContent = anchorNode.getTextPart()

      if anchorOffset == 0 && textContent.lengthAsNSString() != 0 {
        if let prevSibling = anchorNode.getPreviousSibling() {
          target = prevSibling
        } else {
          target = try anchorNode.getParentOrThrow()
        }

        siblings.append(anchorNode)
      } else if anchorOffset == textContent.lengthAsNSString() {
        target = anchorNode
      } else if isTokenOrInert(anchorNode) {
        return false
      } else {
        let danglingTextNodes = try anchorNode.splitText(splitOffsets: [anchorOffset])
        if danglingTextNodes.count == 1 {
          target = danglingTextNodes[0]
        } else {
          target = danglingTextNodes[0]
          siblings.append(contentsOf: Array(danglingTextNodes.dropFirst()))
        }
      }
    }

    let startingNode = target

    siblings.append(contentsOf: nextSiblings)

    let firstNode = nodes.first
    var didReplaceOrMerge = false

    for node in nodes {
      if let node = node as? ElementNode {
        if node == firstNode {
          if let unwrappedTarget = target as? ElementNode,
             unwrappedTarget.isEmpty() &&
              unwrappedTarget.canReplaceWith(replacement: node) {
            try target.replace(replaceWith: node)
            target = node
            didReplaceOrMerge = true
            continue
          }

          let firstDescendant = node.getFirstDescendant()

          if isLeafNode(firstDescendant) {
            guard var element = try firstDescendant?.getParentOrThrow() else {
              throw LexicalError.internal("Could not get firstDescendant's parent")
            }

            while element.isInline() {
              element = try element.getParentOrThrow()
            }

            let children = element.getChildren()

            if let target = target as? ElementNode {
              for child in children {
                try target.append([child])
              }
            } else {
              for child in children.reversed() {
                try target.insertAfter(nodeToInsert: child)
              }

              target = try target.getParentOrThrow()
            }

            try element.remove()
            didReplaceOrMerge = true

            if element === node {
              continue
            }
          }
        }

        if isTextNode(target) {
          target = topLevelElement
        }
      } else if didReplaceOrMerge && !isDecoratorNode(node) && isRootNode(node: target.getParent()) {
        throw LexicalError.invariantViolation("insertNodes: cannot insert a non-element into a root node")
      }

      didReplaceOrMerge = false

      if let unwrappedTarget = target as? ElementNode {
        if let node = node as? DecoratorNode, node.isTopLevel() {
          target = try target.insertAfter(nodeToInsert: node)
        } else if !isElementNode(node: node) {
          if let firstChild = unwrappedTarget.getFirstChild() {
            try firstChild.insertBefore(nodeToInsert: node)
          } else {
            try unwrappedTarget.append([node])
          }

          target = node
        } else {
          if let elementNode = node as? ElementNode {
            if !elementNode.canBeEmpty() && elementNode.isEmpty() {
              continue
            }

            target = try target.insertAfter(nodeToInsert: node)
          }
        }
      } else if !isElementNode(node: node) ||
                  isDecoratorNode(node) && (node as? DecoratorNode)?.isTopLevel() == true {
        target = try target.insertAfter(nodeToInsert: node)
      } else {
        target = try node.getParentOrThrow() // Re-try again with the target being the parent
        continue
      }
    }

    if selectStart {
      if isTextNode(startingNode) {
        if let startingNode = startingNode as? ElementNode {
          try startingNode.select(anchorOffset: nil, focusOffset: nil)
        }
      } else {
        let prevSibling = target.getPreviousSibling()

        if isTextNode(prevSibling) {
          if let prevSibling = prevSibling as? ElementNode {
            try prevSibling.select(anchorOffset: nil, focusOffset: nil)
          }
        } else {
          let index = target.getIndexWithinParent()
          try target.getParentOrThrow().select(anchorOffset: index, focusOffset: index)
        }
      }
    }

    if let unwrappedTarget = target as? ElementNode {
      let lastChild = unwrappedTarget.getLastDescendant()

      if !selectStart {
        if lastChild == nil {
          try unwrappedTarget.select(anchorOffset: nil, focusOffset: nil)
        } else if let lastChild = lastChild as? TextNode {
          try lastChild.select(anchorOffset: nil, focusOffset: nil)
        } else {
          _ = try lastChild?.selectNext(anchorOffset: nil, focusOffset: nil)
        }
      }

      if siblings.count != 0 {
        for sibling in siblings.reversed() {
          let prevParent = try sibling.getParentOrThrow()

          if let unwrappedTarget = target as? ElementNode, !isElementNode(node: sibling) {
            try unwrappedTarget.append([sibling])
            target = sibling
          } else {
            if let elementSibling = sibling as? ElementNode, !elementSibling.canInsertAfter(node: target) {
              let prevParentClone = prevParent.clone()

              try prevParentClone.append([elementSibling])
              try target.insertAfter(nodeToInsert: prevParentClone)
            } else {
              try target.insertAfter(nodeToInsert: sibling)
            }
          }

          if prevParent.isEmpty() && !prevParent.canBeEmpty() {
            try prevParent.remove()
          }
        }
      }
    } else if !selectStart {
      if let target = target as? TextNode {
        try target.select(anchorOffset: nil, focusOffset: nil)
      } else {
        let element = try target.getParentOrThrow()
        if let index = target.getIndexWithinParent() {
          try element.select(anchorOffset: index + 1, focusOffset: index + 1)
        }
      }
    }
    return true
  }

  public func getPlaintext() throws -> String {
    // @alexmattice - replace this with a version driven off a depth first search
    guard let editor = getActiveEditor() else {
      throw LexicalError.invariantViolation("Requires editor")
    }

    let selection = editor.getNativeSelection()

    if let range = selection.range, let textStorage = editor.textStorage {
      return textStorage.attributedSubstring(from: range).string
    } else {
      return ""
    }
  }

  public func getRichtext() throws -> NSAttributedString {
    // @alexmattice - replace this with a version driven off a depth first search
    guard let editor = getActiveEditor() else { return NSAttributedString(string: "") }

    let selection = editor.getNativeSelection()

    if let range = selection.range, let textStorage = editor.textStorage {
      return textStorage.attributedSubstring(from: range)
    } else {
      return NSAttributedString(string: "")
    }
  }

  // MARK: - Internal

  internal func insertParagraph() throws {
    if !isCollapsed() {
      try removeText()
    }

    let anchorOffset = anchor.offset
    var currentElement: ElementNode
    var nodesToMove = [Node]()

    if anchor.type == .text {
      guard let anchorNode = try anchor.getNode() as? TextNode else { return }

      nodesToMove = anchorNode.getNextSiblings().reversed()
      currentElement = try anchorNode.getParentOrThrow()

      if anchorOffset == 0 {
        nodesToMove.append(anchorNode)
      } else if anchorOffset != anchorNode.getTextPartSize() {
        let splitNodes = try anchorNode.splitText(splitOffsets: [anchorOffset])
        if splitNodes.count >= 2 {
          nodesToMove.append(splitNodes[1])
        }
      }
    } else {
      guard let anchorNode = try anchor.getNode() as? ElementNode else { return }

      currentElement = anchorNode
      if let elementNode = currentElement as? RootNode {
        let paragraph = createParagraphNode()
        try paragraph.select(anchorOffset: nil, focusOffset: nil)

        if let child = elementNode.getChildAtIndex(index: anchorOffset) {
          try child.insertBefore(nodeToInsert: paragraph)
        } else {
          try elementNode.append([paragraph])
        }

        return
      }

      nodesToMove = currentElement.getChildren()
      nodesToMove.removeSubrange(0..<anchorOffset)
      nodesToMove.reverse()
    }

    let newElement = try currentElement.insertNewAfter(selection: self)
    if newElement == nil {
      // Handle as a line break insertion
      try insertLineBreak(selectStart: false)
    } else if let newElement = newElement as? ElementNode {
      // move the new element to be before the current element
      if anchorOffset == 0 && nodesToMove.count > 0 {
        try currentElement.insertBefore(nodeToInsert: newElement)
        return
      }

      var firstChild: Node?
      for nodeToMove in nodesToMove {
        if firstChild == nil {
          try newElement.append([nodeToMove])
        } else {
          _ = try firstChild?.insertBefore(nodeToInsert: nodeToMove)
        }

        firstChild = nodeToMove
      }

      if !newElement.canBeEmpty(), newElement.getChildrenSize() == 0 {
        try newElement.selectPrevious(anchorOffset: nil, focusOffset: nil)
        try newElement.remove()
      } else {
        let newSelection = try newElement.selectStart()
        anchor = newSelection.anchor
        focus = newSelection.focus
        dirty = newSelection.dirty
        format = newSelection.format
      }
    }
  }

  // Note that "line break" is different to "paragraph", and pressing return/enter does the latter.
  public func insertLineBreak(selectStart: Bool) throws {
    let lineBreakNode = createLineBreakNode()

    if anchor.type == .element {
      guard let element = try anchor.getNode() as? ElementNode else { return }
      if isRootNode(node: element) {
        try insertParagraph()
      }
    }
    if selectStart {
      _ = try insertNodes(nodes: [lineBreakNode], selectStart: true)
    } else {
      if try insertNodes(nodes: [lineBreakNode], selectStart: false) {
        _ = try lineBreakNode.selectNext(anchorOffset: 0, focusOffset: 0)
      }
    }
  }

  internal func deleteCharacter(isBackwards: Bool) throws {
    if isCollapsed() {
      let node = try anchor.getNode()

      if !isBackwards {
        var requiresCanExtractContents = false

        switch anchor.type {
        case .element:
          if let node = node as? ElementNode {
            requiresCanExtractContents = anchor.offset == node.getChildrenSize()
          }
        case .text:
          if let node = node as? TextNode {
            requiresCanExtractContents = anchor.offset == node.getTextContentSize()
          }
        case .range:
          throw LexicalError.invariantViolation("Need range selection")
        case .node:
          throw LexicalError.invariantViolation("Need node selection")
        case .grid:
          throw LexicalError.invariantViolation("Need grid selection")
        }

        if let nextSibling = try (node.getNextSibling() ?? (try node.getParentOrThrow()).getNextSibling()) as? ElementNode,
           requiresCanExtractContents && !nextSibling.canExtractContents() {
          return
        }
      }

      try modify(alter: .extend, isBackward: isBackwards, granularity: .character)

      if !isCollapsed() {
        let focusNode = focus.type == .text ? (try focus.getNode() as? TextNode) : nil
        let anchorNode = focus.type == .text ? (try anchor.getNode() as? TextNode) : nil

        if let node = focusNode, node.isSegmented() {
          let offset = focus.offset
          let textContentSize = node.getTextContentSize()

          if focusNode == anchorNode &&
              (isBackwards && offset != textContentSize) ||
              (!isBackwards && offset != 0) {
            try removeSegment(node: node, isBackward: isBackwards, offset: offset)
            return
          }
        } else if let node = anchorNode, node.isSegmented() {
          let offset = anchor.offset
          let textContentSize = node.getTextContentSize()

          if focusNode == anchorNode &&
              (isBackwards && offset != textContentSize) ||
              (!isBackwards && offset != 0) {
            try removeSegment(node: node, isBackward: isBackwards, offset: offset)
            return
          }
        }
        // @alexmattice - updateCaretSelectionForUnicodeCharacter(this, isBackward)
      } else if isBackwards && anchor.offset == 0 {
        // Special handling around rich text nodes
        let node = try anchor.type == .element ? anchor.getNode() : (try anchor.getNode().getParentOrThrow())

        if let elementNode = node as? ElementNode, (try elementNode.collapseAtStart(selection: self)) {
          return
        }
      }
    }

    try removeText()
    // NOTE: This is where the logic for dealing with hashtags resides in the web code.
    // updateCaretSelectionForAdjacentHashtags()
  }

  public func deleteWord(isBackwards: Bool) throws {
    if isCollapsed() {
      try modify(alter: .extend, isBackward: isBackwards, granularity: .word)
    }
    try removeText()
  }

  public func deleteLine(isBackwards: Bool) throws {
    if isCollapsed() {
      try modify(alter: .extend, isBackward: isBackwards, granularity: .line)
    }
    try removeText()
  }

  internal func removeText() throws {
    try insertText("")
  }

  internal func modify(alter: NativeSelectionModificationType, isBackward: Bool, granularity: UITextGranularity) throws {
    let collapse = alter == .move

    guard let editor = getActiveEditor() else {
      throw LexicalError.invariantViolation("Cannot be called outside update loop")
    }

    editor.moveNativeSelection(
      type: alter,
      direction: isBackward ? .backward : .forward,
      granularity: granularity)

    let nativeSelection = editor.getNativeSelection()

    try applyNativeSelection(nativeSelection)

    // Because a range works on start and end, we might need to flip
    // to match the range has specifically.

    if let range = nativeSelection.range {
      let anchorLocation = isBackward ? range.location + range.length : range.location
      let focusLocation = isBackward ? range.location : range.location + range.length

      if !collapse && anchorLocation != anchor.offset || focusLocation != focus.offset {
        swapPoints()
      }
    }
  }

  // This method is the equivalent of applyDOMRange()
  public func applyNativeSelection(_ nativeSelection: NativeSelection) throws {
    guard let range = nativeSelection.range else { return }
    try applySelectionRange(range, affinity: range.length == 0 ? .backward : nativeSelection.affinity)
  }

  internal func applySelectionRange(_ range: NSRange, affinity: UITextStorageDirection) throws {
    guard let editor = getActiveEditor() else {
      throw LexicalError.invariantViolation("Calling applyNativeSelection when no active editor")
    }

    let anchorOffset = affinity == .forward ? range.location : range.location + range.length
    let focusOffset = affinity == .forward ? range.location + range.length : range.location

    if let anchor = try pointAtStringLocation(anchorOffset, searchDirection: affinity, rangeCache: editor.rangeCache),
       let focus = try pointAtStringLocation(focusOffset, searchDirection: affinity, rangeCache: editor.rangeCache) {
      self.anchor = anchor
      self.focus = focus
    }
  }

  internal func formatText(formatType: TextFormatType) throws {
    if isCollapsed() {
      toggleFormat(type: formatType)
      return
    }

    let selectedNodes = try getNodes()
    guard var firstNode = selectedNodes.first, let lastNode = selectedNodes.last else { return }

    var firstNextFormat = TextFormat()
    for node in selectedNodes {
      if let node = node as? TextNode {
        firstNextFormat = node.getFormatFlags(type: formatType)
        break
      }
    }

    let isBefore = try anchor.isBefore(point: focus)
    var startOffset = isBefore ? anchor.offset : focus.offset
    var endOffset = isBefore ? focus.offset : anchor.offset

    // This is the case where the user only selected the very end of the
    // first node so we don't want to include it in the formatting change.
    if startOffset == firstNode.getTextPartSize() {
      if let nextSibling = firstNode.getNextSibling() as? TextNode {
        // we basically make the second node the firstNode, changing offsets accordingly
        anchor.offset = 0
        startOffset = 0
        firstNode = nextSibling
        firstNextFormat = nextSibling.getFormat()
      }
    }

    // This is the case where we only selected a single node
    if firstNode === lastNode {
      if let textNode = firstNode as? TextNode {
        if anchor.type == .element && focus.type == .element {
          try textNode.setFormat(format: firstNextFormat)
          let newSelection = try textNode.select(anchorOffset: startOffset, focusOffset: endOffset)
          updateSelection(
            anchor: newSelection.anchor,
            focus: newSelection.focus,
            format: firstNextFormat,
            isDirty: newSelection.dirty)
          return
        }

        startOffset = anchor.offset > focus.offset ? focus.offset : anchor.offset
        endOffset = anchor.offset > focus.offset ? anchor.offset : focus.offset

        // No actual text is selected, so do nothing.
        if startOffset == endOffset {
          return
        }

        // The entire node is selected, so just format it
        if startOffset == 0 && endOffset == textNode.getTextPartSize() {
          try textNode.setFormat(format: firstNextFormat)
          let newSelection = try textNode.select(anchorOffset: startOffset, focusOffset: endOffset)
          updateSelection(
            anchor: newSelection.anchor,
            focus: newSelection.focus,
            format: firstNextFormat,
            isDirty: newSelection.dirty)
        } else {
          // node is partially selected, so split it into two nodes and style the selected one.
          let splitNodes = try textNode.splitText(splitOffsets: [startOffset, endOffset])
          let replacement = startOffset == 0 ? splitNodes[0] : splitNodes[1]
          try replacement.setFormat(format: firstNextFormat)
          let newSelection = try replacement.select(anchorOffset: 0, focusOffset: endOffset - startOffset)
          updateSelection(
            anchor: newSelection.anchor,
            focus: newSelection.focus,
            format: firstNextFormat,
            isDirty: newSelection.dirty)
        }

        format = firstNextFormat
      }
    } else {
      // multiple nodes selected
      if var textNode = firstNode as? TextNode {
        if startOffset != 0 {
          // the entire first node isn't selected, so split it
          let splitNodes = try textNode.splitText(splitOffsets: [startOffset])
          if splitNodes.count >= 1 {
            textNode = splitNodes[1]
          }

          startOffset = 0
        }
        try textNode.setFormat(format: firstNextFormat)

        // update selection
        if isBefore {
          anchor.updatePoint(key: textNode.key, offset: startOffset, type: .text)
        } else {
          focus.updatePoint(key: textNode.key, offset: startOffset, type: .text)
        }

        format = firstNextFormat
      }

      var lastNextFormat = firstNextFormat

      if var textNode = lastNode as? TextNode {
        lastNextFormat = textNode.getFormatFlags(type: formatType, alignWithFormat: firstNextFormat)
        // if the offset is 0, it means no actual characters are selected,
        // so we skip formatting the last node altogether.
        if endOffset != 0 {
          // if the entire last node isn't selected, split it
          if endOffset != textNode.getTextPartSize() {
            let lastNodes = try textNode.splitText(splitOffsets: [endOffset])
            if lastNodes.count >= 1 {
              textNode = lastNodes[0]
            }
          }

          try textNode.setFormat(format: lastNextFormat)
          // update selection
          if isBefore {
            focus.updatePoint(key: textNode.key, offset: endOffset, type: .text)
          } else {
            anchor.updatePoint(key: textNode.key, offset: endOffset, type: .text)
          }
        }
      }

      // deal with all the nodes in between
      for index in 1..<selectedNodes.count - 1 {
        let selectedNode = selectedNodes[index]
        let selectedNodeKey = selectedNode.getKey()

        if let textNode = selectedNode as? TextNode,
           selectedNodeKey != firstNode.getKey(),
           selectedNodeKey != lastNode.getKey() {
          let selectedNextFormat = textNode.getFormatFlags(type: formatType, alignWithFormat: lastNextFormat)
          try textNode.setFormat(format: selectedNextFormat)
        }
      }
    }
  }

  internal func clearFormat() {
    format = TextFormat()
  }

  // MARK: - Private

  private func updateSelection(anchor: Point, focus: Point, format: TextFormat, isDirty: Bool) {
    self.anchor.updatePoint(key: anchor.key, offset: anchor.offset, type: anchor.type)
    self.focus.updatePoint(key: focus.key, offset: focus.offset, type: focus.type)
    self.format = format
    self.dirty = isDirty
  }

  private func toggleFormat(type: TextFormatType) {
    format = toggleTextFormatType(format: format, type: type, alignWithFormat: nil)
    dirty = true
  }

  private func swapPoints() {
    let anchorKey = anchor.key
    let anchorOffset = anchor.offset
    let anchorType = anchor.type

    anchor.key = focus.key
    anchor.offset = focus.offset
    anchor.type = focus.type

    focus.key = anchorKey
    focus.offset = anchorOffset
    focus.type = anchorType
  }
}

extension RangeSelection: Equatable {
  public static func == (lhs: RangeSelection, rhs: RangeSelection) -> Bool {
    return lhs.anchor == rhs.anchor &&
      lhs.focus == rhs.focus &&
      lhs.format == rhs.format
  }
}

extension RangeSelection: CustomDebugStringConvertible {
  public var debugDescription: String {
    return "\tanchor { \(anchor)\n\tfocus { \(focus)"
  }
}
