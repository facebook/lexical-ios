/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical
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
      if let self = self {
        self.updateToolbar()
      }
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
    
    toolbar.items = [/* undo, redo, */ paragraph, bold, italic, underline, strikethrough, inlineCode /*, link */]
  }
  
  func updateToolbar() {
    if let selection = getSelection() {
      guard let anchorNode = try? selection.anchor.getNode() else { return }
            
      var element =
      isRootNode(node: anchorNode)
      ? anchorNode
      : findMatchingParent(startingNode: anchorNode, findFn: { e in
        let parent = e.getParent()
        return parent != nil && isRootNode(node: parent)
      })
      
      if element == nil {
        element = anchorNode.getTopLevelElementOrThrow();
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
      } else {
        paragraphButton?.image = UIImage(systemName: "paragraph")
      }
      
      boldButton?.isSelected = selection.hasFormat(type: .bold)
      italicButton?.isSelected = selection.hasFormat(type: .italic)
      underlineButton?.isSelected = selection.hasFormat(type: .underline)
      strikethroughButton?.isSelected = selection.hasFormat(type: .strikethrough)
      inlineCodeButton?.isSelected = selection.hasFormat(type: .code)
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
      })
    ]
  }
  
  private func setBlock(creationFunc: () -> ElementNode) {
    try? editor?.update {
      if let selection = getSelection() {
        setBlocksType(selection: selection, createElement: creationFunc)
      }
    }
  }
  
  private var paragraphMenu: UIMenu {
    return UIMenu(title: "Paragraph Style", image: nil, identifier: nil, options: [], children: self.paragraphMenuItems)
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
    
  }
}
