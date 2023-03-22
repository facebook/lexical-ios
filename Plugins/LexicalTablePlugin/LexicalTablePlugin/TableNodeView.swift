// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Lexical
import UIKit

class TableNodeView: UIView {

  internal var borderColor: UIColor = .lightGray

  override init(frame: CGRect) {
    super.init(frame: frame)
    let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(gestureRecognizer:)))
    addGestureRecognizer(gestureRecognizer)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  internal var numColumns: Int = 1 {
    didSet {
      setNeedsDisplay()
    }
  }

  internal var numRows: Int = 1 {
    didSet {
      setNeedsDisplay()
    }
  }

  override var frame: CGRect {
    didSet {
      setNeedsDisplay()
    }
  }

  internal var rows: [TableRow] = [] {
    didSet {
      setNeedsDisplay()
    }
  }

  override func draw(_ rect: CGRect) {
    // Currently: assuming all cells in first row are populated, and column widths are defined by cells in first row
    guard let context = UIGraphicsGetCurrentContext() else { return }
    let lineWidth: CGFloat = 1.0
    context.setLineWidth(lineWidth)
    context.setStrokeColor(borderColor.cgColor) // TODO: fetch this from attributes
    context.setFillColor((backgroundColor ?? UIColor.white).cgColor)

    // All TextKit drawing is done after all custom table drawing, in order to avoid missing lines.
    var textKitDrawQueue: [TableCell] = []

    // 1. Cache widths
    guard let firstRow = rows.first else { return }
    var columnWidths: [CGFloat] = []
    var totalWidth: CGFloat = 0.0
    for cell in firstRow.cells {
      guard let cell = cell, let width = cell.cachedWidth else { return }
      columnWidths.append(width)
      totalWidth += lineWidth
      totalWidth += width
    }
    totalWidth += lineWidth // for the line drawn after the cells

    // 2. Draw rows, including lines, and cache cumulative height
    var cumulativeHeight: CGFloat = 0.0
    for row in rows {
      // draw boundary before
      context.move(to: CGPoint(x: 0.5, y: cumulativeHeight + 0.5))
      context.addLine(to: CGPoint(x: totalWidth + 0.5, y: cumulativeHeight + 0.5))

      // draw cells, track cumulative width
      var cumulativeWidth = lineWidth
      var thisHeight: CGFloat = 0.0
      for (i, cell) in row.cells.enumerated() {
        guard let cell = cell else { continue }
        let drawingPoint = CGPoint(x: cumulativeWidth, y: cumulativeHeight)
        cell.cachedOrigin = drawingPoint // cache the point that the cell needs drawing at
        textKitDrawQueue.append(cell) // queue up this cell for later drawing
        cumulativeWidth += columnWidths[i]
        cumulativeWidth += lineWidth
        thisHeight = max(thisHeight, cell.cachedHeight ?? 0)
      }
      cumulativeHeight += thisHeight
    }

    // divider after last row
    context.move(to: CGPoint(x: 0.5, y: cumulativeHeight + 0.5))
    context.addLine(to: CGPoint(x: totalWidth + 0.5, y: cumulativeHeight + 0.5))

    // 3. Draw vertical lines
    var cumulativeWidth = 0.0
    for colWidth in columnWidths {
      context.move(to: CGPoint(x: cumulativeWidth + 0.5, y: 0.5))
      context.addLine(to: CGPoint(x: cumulativeWidth + 0.5, y: cumulativeHeight + 0.5))
      cumulativeWidth += lineWidth
      cumulativeWidth += colWidth
    }

    // divider after last col
    context.move(to: CGPoint(x: cumulativeWidth + 0.5, y: 0.5))
    context.addLine(to: CGPoint(x: cumulativeWidth + 0.5, y: cumulativeHeight + 0.5))

    context.strokePath()

    // Now it's safe to do TextKit drawing
    for cell in textKitDrawQueue {
      guard let point = cell.cachedOrigin else { continue }
      cell.textKitContext.draw(inContext: context, point: point)
    }
  }

  @objc internal func handleTap(gestureRecognizer: UITapGestureRecognizer) {
    let pointInView = gestureRecognizer.location(in: self)

    for row in rows {
      for cell in row.cells {
        if let cell = cell {
          let textKitContext = cell.textKitContext
          guard let textContainerOrigin = cell.cachedOrigin else { continue }
          let pointInTextContainer = CGPoint(x: pointInView.x - textKitContext.textContainerInsets.left - textContainerOrigin.x,
                                             y: pointInView.y - textKitContext.textContainerInsets.top - textContainerOrigin.y)
          let textContainerRelativeRect = CGRect(x: 0, y: 0, width: cell.cachedWidth ?? 0, height: cell.cachedHeight ?? 0)
          if !textContainerRelativeRect.contains(pointInTextContainer) { continue }
          let indexOfCharacter = textKitContext.layoutManager.characterIndex(for: pointInTextContainer,
                                                                             in: textKitContext.textContainer,
                                                                             fractionOfDistanceBetweenInsertionPoints: nil)
          if indexOfCharacter >= textKitContext.textStorage.length { continue }
          let attributes = textKitContext.textStorage.attributes(at: indexOfCharacter, effectiveRange: nil)

          if let link = attributes[.link] {
            if let link = link as? URL {
              textKitContext.editor.dispatchCommand(type: .linkTapped, payload: link)
            } else if let link = link as? String {
              if let linkURL = URL(string: link) {
                textKitContext.editor.dispatchCommand(type: .linkTapped, payload: linkURL)
              }
            }
          }
        }
      }
    }
  }
}
