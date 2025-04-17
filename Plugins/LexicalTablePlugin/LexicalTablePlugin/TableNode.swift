/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import AVFoundation
import Foundation
import Lexical
import UIKit

internal let minimumCellWidth: CGFloat = 150.0
let lineWidth = CGFloat(1.0)

public extension NodeType {
  static let table = NodeType(rawValue: "table")
}

extension NSAttributedString.Key {
  // table node also uses .backgroundColor built in attribute
  public static let borderColor: NSAttributedString.Key = .init(rawValue: "borderColor")
}

public class TableCell {
  internal init(textKitContext: LexicalReadOnlyTextKitContext, cachedHeight: CGFloat? = nil) {
    self.textKitContext = textKitContext
    self.cachedHeight = cachedHeight
  }

  var textKitContext: LexicalReadOnlyTextKitContext
  var cachedHeight: CGFloat?
  var cachedWidth: CGFloat?
  var cachedOrigin: CGPoint?  // This is set by the TableNodeView when drawing
}

public class TableRow {  // only public to use in initialiser
  var cells: [TableCell?] = []
}

public class TableNode: DecoratorNode {

  public enum ThemeSubtype {
    public static let tableDrawing = "tableDrawing"
  }

  var numColumns: Int = 0
  var numRows: Int = 0

  fileprivate var rows: [TableRow] = []

  public required init(numColumns: Int, numRows: Int, rows newRows: [TableRow]? = nil, key: NodeKey? = nil) {
    super.init(key)

    self.numColumns = numColumns
    self.numRows = numRows

    if let newRows {
      self.rows = newRows
      return
    }

    // No rows were passed in, so create new rows/cells

    // stuff to capture in listener block
    guard let parentEditor = getActiveEditor() else {
      fatalError()
    }
    let tableKey = self.key

    guard let editorConfigFactory = try? Self.editorConfigFactory() else { return }

    for r in 0..<numRows {
      let row = TableRow()
      rows.append(row)

      for c in 0..<numColumns {
        let cell = Self.createCell(editorConfig: editorConfigFactory(), parentEditor: parentEditor, tableKey: tableKey, row: r, col: c)
        row.cells.append(cell)

        do {
          try cell.textKitContext.editor.update {
            let node = TextNode()
            try node.setText("Row \(r) cell \(c) and a bunch more text")
            guard let para = getRoot()?.getFirstChild() as? ParagraphNode else { return }
            try para.append([node])
          }
        } catch {
          print("error \(error)")
        }
      }
    }
  }

  private static func editorConfigFactory() throws -> EditorConfigFactory {
    guard let tablePlugin = try? TablePlugin.installedInstance() else {
      throw LexicalError.invariantViolation("No table plugin installed instance")
    }
    return tablePlugin.editorConfigFactory
  }

  private static func createCell(editorConfig: EditorConfig, parentEditor: Editor, tableKey: NodeKey, row: Int, col: Int) -> TableCell {
    let textKitContext = LexicalReadOnlyTextKitContext(editorConfig: editorConfig, featureFlags: FeatureFlags())
    textKitContext.editor.parentEditor = parentEditor
    let cell = TableCell(textKitContext: textKitContext)

    _ = textKitContext.editor.registerUpdateListener { [weak parentEditor] activeEditorState, previousEditorState, dirtyNodes in
      try? parentEditor?.update {
        guard let tableNode = getNodeByKey(key: tableKey) as? TableNode else {
          return
        }
        tableNode.cellChangedSize(row: row, col: col)
      }
    }

    return cell
  }

  override public func didMoveTo(newEditor editor: Editor) {
    for row in rows {
      for cell in row.cells {
        if let cell {
          cell.textKitContext.editor.parentEditor = editor
        }
      }
    }
  }

  required init(_ key: NodeKey? = nil) {
    super.init(key)
  }

  public required init(from decoder: Decoder) throws {
    try super.init(from: decoder)
  }

  override public class func getType() -> NodeType {
    .table
  }

  override public func clone() -> Self {
    Self(numColumns: numColumns, numRows: numRows, rows: rows, key: key)
  }

  public func editorForCell(col: Int, row: Int) throws -> Editor {
    if col < 0 || col >= numColumns || row < 0 || row >= numRows {
      throw LexicalError.invariantViolation("Cell index out of bounds")
    }
    let rowObj = rows[row]
    let cell = rowObj.cells[col]

    if let cell {
      return cell.textKitContext.editor
    }

    let editorConfigFactory = try Self.editorConfigFactory()
    let tableKey = self.key
    guard let parentEditor = getActiveEditor() else {
      throw LexicalError.invariantViolation("Requires update block")
    }
    let newCell = Self.createCell(editorConfig: editorConfigFactory(), parentEditor: parentEditor, tableKey: tableKey, row: row, col: col)
    rowObj.cells[col] = newCell

    return newCell.textKitContext.editor
  }

  override public func createView() -> UIView {
    let tableNodeView = TableNodeView(frame: .zero)
    if let editor = getActiveEditor() {
      let theme = editor.getTheme()
      if let tableTheme = theme.getValue(.table, withSubtype: ThemeSubtype.tableDrawing) {
        if let borderColor = tableTheme[.borderColor] as? UIColor {
          tableNodeView.borderColor = borderColor
        }
        if let backgroundColor = tableTheme[NSAttributedString.Key.backgroundColor] as? UIColor {
          tableNodeView.backgroundColor = backgroundColor
        }
      }
    }

    let scrollableWrapperView = TableNodeScrollableWrapperView(frame: .zero)
    scrollableWrapperView.tableNodeView = tableNodeView

    return scrollableWrapperView
  }

  override open func decorate(view: UIView) {
    if let wrapperView = view as? TableNodeScrollableWrapperView, let tableNodeView = wrapperView.tableNodeView {
      tableNodeView.numColumns = getLatest().numColumns
      tableNodeView.numRows = getLatest().numRows
      tableNodeView.rows = rows
    }
  }

  override open func sizeForDecoratorView(textViewWidth: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGSize {

    // the +1 is because there is one more line than columns
    var cellWidth = floor((Double(textViewWidth) - (Double(numColumns + 1) * lineWidth)) / Double(numColumns))

    if cellWidth < minimumCellWidth {
      cellWidth = minimumCellWidth
    }

    var cumulativeHeight = CGFloat(0)

    for row in getLatest().rows {
      var maxRowSize = CGFloat(0)
      for cell in row.cells {
        if let cell, cellWidth != cell.cachedWidth {
          cell.cachedWidth = cellWidth
          cell.textKitContext.setTextContainerSizeWithUnlimitedHeight(forWidth: cellWidth)
          cell.cachedHeight = cell.textKitContext.requiredSize().height
        }
        maxRowSize = max(cell?.cachedHeight ?? 0, maxRowSize)
      }
      cumulativeHeight += maxRowSize
      cumulativeHeight += lineWidth
    }
    cumulativeHeight += lineWidth
    return CGSize(width: min(((cellWidth + lineWidth) * Double(numColumns)) + lineWidth, textViewWidth), height: cumulativeHeight)
  }

  fileprivate func cellChangedSize(row rowNum: Int, col colNum: Int) {
    guard let node = try? getWritable() else { return }
    let row = node.rows[rowNum]
    if let cell = row.cells[colNum] {
      cell.cachedHeight = cell.textKitContext.requiredSize().height
    }
  }
}
