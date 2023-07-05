/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical
import LexicalLinkPlugin
import LexicalInlineImagePlugin
import LexicalListPlugin
import UIKit

public class ToolbarPlugin: Plugin {
  private var _toolbar: UIToolbar

  weak var editor: Editor?
  weak var viewControllerForPresentation: UIViewController?

  init(viewControllerForPresentation: UIViewController) {
    self._toolbar = UIToolbar()
    self.viewControllerForPresentation = viewControllerForPresentation
    setUpToolbar()
  }

  // MARK: - Plugin API

  public func setUp(editor: Editor) {
    self.editor = editor

    _ = editor.registerUpdateListener { [weak self] activeEditorState, previousEditorState, dirtyNodes in
      if let self {
        self.updateToolbar()
      }
    }

    _ = editor.registerCommand(type: .linkTapped) { [weak self] payload in
      if let self, let payload = payload as? URL, let rangeSelection = try? getSelection() as? RangeSelection, let startSearch = try? self.getSelectedNode(selection: rangeSelection) {

        guard let link = getNearestNodeOfType(node: startSearch, type: .link) else {
          return false
        }

        guard let element = link.getParent() else {
          return false
        }
        var newSelection: RangeSelection?
        if let index = link.getIndexWithinParent() {
          newSelection = try? element.select(anchorOffset: index, focusOffset: index + 1)
        }
        guard let selection = newSelection else {
          return false
        }

        _ = self.showLinkActionSheet(url: payload.absoluteString, selection: selection)
        return true
      }
      return false // shouldn't happen!
    }
  }

  public func tearDown() {
  }

  // MARK: - Public accessors

  public var toolbar: UIToolbar {
    get {
      _toolbar
    }
  }

  // MARK: - Private helpers

  var undoButton: UIBarButtonItem?
  var redoButton: UIBarButtonItem?
  var paragraphButton: UIBarButtonItem?
  var boldButton: UIBarButtonItem?
  var italicButton: UIBarButtonItem?
  var underlineButton: UIBarButtonItem?
  var strikethroughButton: UIBarButtonItem?
  var inlineCodeButton: UIBarButtonItem?
  var linkButton: UIBarButtonItem?
  var increaseIndentButton: UIBarButtonItem?
  var decreaseIndentButton: UIBarButtonItem?
  var insertImageButton: UIBarButtonItem?

  private func setUpToolbar() {
    let undo = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.backward"),
                               style: .plain,
                               target: self,
                               action: #selector(undo))
    self.undoButton = undo

    let redo = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.forward"),
                               style: .plain,
                               target: self,
                               action: #selector(redo))
    self.redoButton = redo

    let paragraph = UIBarButtonItem(image: UIImage(systemName: "paragraph"), menu: self.paragraphMenu)
    self.paragraphButton = paragraph

    let bold = UIBarButtonItem(image: UIImage(systemName: "bold"),
                               style: .plain,
                               target: self,
                               action: #selector(toggleBold))
    self.boldButton = bold

    let italic = UIBarButtonItem(image: UIImage(systemName: "italic"),
                                 style: .plain,
                                 target: self,
                                 action: #selector(toggleItalic))
    self.italicButton = italic

    let underline = UIBarButtonItem(image: UIImage(systemName: "underline"),
                                    style: .plain,
                                    target: self,
                                    action: #selector(toggleUnderline))
    self.underlineButton = underline

    let strikethrough = UIBarButtonItem(image: UIImage(systemName: "strikethrough"),
                                        style: .plain,
                                        target: self,
                                        action: #selector(toggleStrikethrough))
    self.strikethroughButton = strikethrough

    let inlineCode = UIBarButtonItem(image: UIImage(systemName: "chevron.left.forwardslash.chevron.right"),
                                     style: .plain,
                                     target: self,
                                     action: #selector(toggleInlineCode))
    self.inlineCodeButton = inlineCode

    let link = UIBarButtonItem(image: UIImage(systemName: "link"),
                               style: .plain,
                               target: self,
                               action: #selector(link))
    self.linkButton = link

    let increaseIndent = UIBarButtonItem(image: UIImage(systemName: "increase.indent"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(increaseIndent))
    self.increaseIndentButton = increaseIndent

    let decreaseIndent = UIBarButtonItem(image: UIImage(systemName: "decrease.indent"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(decreaseIndent))
    self.decreaseIndentButton = decreaseIndent

    let insertImage = UIBarButtonItem(image: UIImage(systemName: "photo"), menu: self.imageMenu)
    self.insertImageButton = insertImage

    toolbar.items = [/* undo, redo, */ paragraph, bold, italic, underline, strikethrough, inlineCode, link, decreaseIndent, increaseIndent, insertImage]
  }

  private func updateToolbar() {
    if let selection = try? getSelection() as? RangeSelection {
      guard let anchorNode = try? selection.anchor.getNode() else { return }

      var element =
        isRootNode(node: anchorNode)
        ? anchorNode
        : findMatchingParent(startingNode: anchorNode, findFn: { e in
          let parent = e.getParent()
          return parent != nil && isRootNode(node: parent)
        })

      if element == nil {
        element = anchorNode.getTopLevelElementOrThrow()
      }

      // derive paragraph style
      if let heading = element as? HeadingNode {
        if heading.getTag() == .h1 {
          paragraphButton?.image = UIImage(named: "h1")
        } else {
          paragraphButton?.image = UIImage(named: "h2")
        }
      } else if element is CodeNode {
        paragraphButton?.image = UIImage(systemName: "chevron.left.forwardslash.chevron.right")
      } else if element is QuoteNode {
        paragraphButton?.image = UIImage(systemName: "quote.opening")
      } else if let element = element as? ListNode {
        var listType: ListType = .bullet
        if let parentList: ListNode = getNearestNodeOfType(node: anchorNode, type: .list) {
          listType = parentList.getListType()
        } else {
          listType = element.getListType()
        }
        switch listType {
        case .bullet:
          paragraphButton?.image = UIImage(systemName: "list.bullet")
        case .number:
          paragraphButton?.image = UIImage(systemName: "list.number")
        case .check:
          paragraphButton?.image = UIImage(systemName: "checklist")
        }
      } else {
        paragraphButton?.image = UIImage(systemName: "paragraph")
      }

      boldButton?.isSelected = selection.hasFormat(type: .bold)
      italicButton?.isSelected = selection.hasFormat(type: .italic)
      underlineButton?.isSelected = selection.hasFormat(type: .underline)
      strikethroughButton?.isSelected = selection.hasFormat(type: .strikethrough)
      inlineCodeButton?.isSelected = selection.hasFormat(type: .code)

      // Update links
      do {
        let selectedNode = try getSelectedNode(selection: selection)
        let selectedNodeParent = selectedNode.getParent()
        if selectedNode is LinkNode || selectedNodeParent is LinkNode {
          linkButton?.isSelected = true
        } else {
          linkButton?.isSelected = false
        }
      } catch {
        print("Error getting the selected Node: \(error.localizedDescription)")
      }
    }
  }

  // MARK: - Paragraph Styles

  private var paragraphMenuItems: [UIAction] {
    return [
      UIAction(title: "Normal", image: UIImage(systemName: "paragraph"), handler: { (_) in
        self.setBlock {
          createParagraphNode()
        }
      }),
      UIAction(title: "Heading 1", image: UIImage(named: "h1"), handler: { (_) in
        self.setBlock {
          createHeadingNode(headingTag: .h1)
        }
      }),
      UIAction(title: "Heading 2", image: UIImage(named: "h2"), handler: { (_) in
        self.setBlock {
          createHeadingNode(headingTag: .h2)
        }
      }),
      UIAction(title: "Code Block", image: UIImage(systemName: "chevron.left.forwardslash.chevron.right"), handler: { (_) in
        self.setBlock {
          createCodeNode()
        }
      }),
      UIAction(title: "Quote", image: UIImage(systemName: "quote.opening"), handler: { (_) in
        self.setBlock {
          createQuoteNode()
        }
      }),
      UIAction(title: "Bulleted List", image: UIImage(systemName: "list.bullet"), handler: { (_) in
        self.editor?.dispatchCommand(type: .insertUnorderedList)
      }),
      UIAction(title: "Numbered List", image: UIImage(systemName: "list.number"), handler: { (_) in
        self.editor?.dispatchCommand(type: .insertOrderedList)
      })
    ]
  }

  private var imageMenuItems: [UIAction] {
    return [
      UIAction(title: "Insert Sample Image", image: UIImage(systemName: "photo"), handler: { [weak self] (_) in
        self?.insertSampleImage()
      }),
    ]
  }

  private func setBlock(creationFunc: () -> ElementNode) {
    try? editor?.update {
      if let selection = try getSelection() as? RangeSelection {
        setBlocksType(selection: selection, createElement: creationFunc)
      }
    }
  }

  private var paragraphMenu: UIMenu {
    return UIMenu(title: "Paragraph Style", image: nil, identifier: nil, options: [], children: self.paragraphMenuItems)
  }

  private var imageMenu: UIMenu {
    return UIMenu(title: "Insert Image", image: nil, identifier: nil, options: [], children: self.imageMenuItems)
  }

  // MARK: - Button actions

  @objc private func undo() {
  }
  @objc private func redo() {
  }

  @objc private func toggleBold() {
    editor?.dispatchCommand(type: .formatText, payload: TextFormatType.bold)
  }
  @objc private func toggleItalic() {
    editor?.dispatchCommand(type: .formatText, payload: TextFormatType.italic)
  }
  @objc private func toggleUnderline() {
    editor?.dispatchCommand(type: .formatText, payload: TextFormatType.underline)
  }
  @objc private func toggleStrikethrough() {
    editor?.dispatchCommand(type: .formatText, payload: TextFormatType.strikethrough)
  }
  @objc private func toggleInlineCode() {
    editor?.dispatchCommand(type: .formatText, payload: TextFormatType.code)
  }
  @objc private func link() {
    showLinkEditor()
  }
  @objc private func increaseIndent() {
    editor?.dispatchCommand(type: .indentContent, payload: nil)
  }
  @objc private func decreaseIndent() {
    editor?.dispatchCommand(type: .outdentContent, payload: nil)
  }

  private func insertSampleImage() {
    guard let url = Bundle.main.url(forResource: "lexical-logo", withExtension: "png") else {
      return
    }
    try? editor?.update {
      let imageNode = ImageNode(url: url.absoluteString, size: CGSize(width: 300, height: 300), sourceID: "")
      if let selection = try getSelection() {
        _ = try selection.insertNodes(nodes: [imageNode], selectStart: false)
      }
    }
  }

  // MARK: - Link handling

  internal func showLinkEditor() {
    guard let editor else { return }
    do {
      try editor.read {
        guard let selection = try getSelection() as? RangeSelection else { return }

        let node = try getSelectedNode(selection: selection)
        if let node = node as? LinkNode {
          _ = showLinkActionSheet(url: node.getURL(), selection: selection)
        } else if let parent = node.getParent() as? LinkNode {
          _ = showLinkActionSheet(url: parent.getURL(), selection: selection)
        } else {
          let urlString = "https://"
          showAlert(url: urlString, isEdit: false)
        }
      }
    } catch {
      print("Error getting the selected node: \(error.localizedDescription)")
    }
  }

  internal func getSelectedNode(selection: RangeSelection) throws -> Node {
    let anchor = selection.anchor
    let focus = selection.focus

    let anchorNode = try selection.anchor.getNode()
    let focusNode = try selection.focus.getNode()

    if anchorNode == focusNode {
      return anchorNode
    }

    let isBackward = try selection.isBackward()
    if isBackward {
      return try focus.isAtNodeEnd() ? anchorNode : focusNode
    } else {
      return try anchor.isAtNodeEnd() ? focusNode : anchorNode
    }
  }

  func showAlert(url: String?, isEdit: Bool, selection: RangeSelection? = nil) {
    guard let url, let editor else { return }

    var originalSelection: RangeSelection?

    do {
      try editor.read {
        originalSelection = try getSelection() as? RangeSelection
      }
    } catch {
      print("Error: \(error.localizedDescription)")
    }

    let title = isEdit ? "Edit Link" : "Link"
    let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
    let doneAction = UIAlertAction(title: "Done", style: .default) { [weak self, weak alertController] action in
      guard let strongSelf = self else { return }

      if let textField = alertController?.textFields?.first, let originalSelection {

        let updateSelection = isEdit ? selection : originalSelection
        strongSelf.editor?.dispatchCommand(type: .link, payload: LinkPayload(urlString: textField.text ?? "", originalSelection: updateSelection))
      }
    }

    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

    alertController.addTextField { textField in
      textField.layer.cornerRadius = 20
      textField.text = url
    }

    alertController.addAction(doneAction)
    alertController.addAction(cancelAction)

    viewControllerForPresentation?.present(alertController, animated: true)
  }

  public func showLinkActionSheet(url: String, selection: RangeSelection?) -> Bool {
    let actionSheet = UIAlertController(title: "Link Action", message: nil, preferredStyle: .actionSheet)

    let removeLinkAction = UIAlertAction(title: "Remove Link", style: .default) { [weak self] action in
      guard let strongSelf = self else { return }

      strongSelf.editor?.dispatchCommand(type: .link, payload: LinkPayload(urlString: nil, originalSelection: selection))
    }

    let visitLinkAction = UIAlertAction(title: "Visit Link", style: .default) { [weak self] action in
      guard let strongSelf = self else { return }
      guard let url = URL(string: url) else { return }

      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
      } else {
        let title = "Error"
        let message = "Invalid URL"
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okButton = UIAlertAction(title: "OK", style: .cancel)
        alertController.addAction(okButton)

        strongSelf.viewControllerForPresentation?.present(alertController, animated: true)
      }
    }

    let editLinkAction = UIAlertAction(title: "Edit Link", style: .default) { [weak self] action in
      guard let strongSelf = self else { return }
      guard let url = URL(string: url) else { return }

      strongSelf.showAlert(url: url.absoluteString, isEdit: true, selection: selection)
    }

    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

    actionSheet.addAction(removeLinkAction)
    actionSheet.addAction(visitLinkAction)
    actionSheet.addAction(editLinkAction)
    actionSheet.addAction(cancelAction)

    viewControllerForPresentation?.present(actionSheet, animated: true)

    return false
  }
}
