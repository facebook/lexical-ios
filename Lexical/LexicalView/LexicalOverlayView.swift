//
//  LexicalOverlayView.swift
//
//
//  Created by Michael Hahn on 7/30/24.
//

import Foundation
import UIKit

class LexicalOverlayView: UIView {
  private weak var textView: UITextView?

  init(textView: UITextView) {
    self.textView = textView
    super.init(frame: .zero)
    self.backgroundColor = .clear  // Make it transparent
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    if shouldInterceptTap(at: point) {
      return self
    }

    return textView?.hitTest(convert(point, to: textView), with: event)
      ?? super.hitTest(point, with: event)
  }

  func shouldInterceptTap(at point: CGPoint) -> Bool {
    guard let textView = textView as? TextView,
      let textStorage = textView.textStorage as? TextStorage
    else { return false }

    let pointInTextView = convert(point, to: textView)

    let pointInTextContainer = CGPoint(
      x: pointInTextView.x - textView.textContainerInset.left,
      y: pointInTextView.y - textView.textContainerInset.top
    )

    let indexOfCharacter = textView.layoutManager.characterIndex(
      for: pointInTextContainer,
      in: textView.textContainer,
      fractionOfDistanceBetweenInsertionPoints: nil
    )
    let glyphIndex = textView.layoutManager.glyphIndex(
      for: pointInTextContainer, in: textView.textContainer)
    let lineFragmentRect = textView.layoutManager.lineFragmentRect(
      forGlyphAt: glyphIndex, effectiveRange: nil)
    let firstCharacterRect = textView.layoutManager.boundingRect(
      forGlyphRange: NSRange(location: glyphIndex, length: 1),
      in: textView.textContainer
    )
    if !lineFragmentRect.contains(pointInTextContainer) {
      return false
    }

    let attributes = textStorage.attributes(at: indexOfCharacter, effectiveRange: nil)
    for plugin in textView.editor.plugins {
      if let hit = plugin.hitTest?(
        at: pointInTextContainer, lineFragmentRect: lineFragmentRect,
        firstCharacterRect: firstCharacterRect, attributes: attributes), hit
      {
        return true
      }
    }
    return false
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    if let touch = touches.first {
      let location = touch.location(in: self)
      handleTouchEvent(at: location)
    }
  }

  private func handleTouchEvent(at point: CGPoint) {
    guard let textView = textView as? TextView,
      let textStorage = textView.textStorage as? TextStorage
    else { return }

    let pointInTextContainer = CGPoint(
      x: point.x - textView.textContainerInset.left,
      y: point.y - textView.textContainerInset.top
    )

    let indexOfCharacter = textView.layoutManager.characterIndex(
      for: pointInTextContainer,
      in: textView.textContainer,
      fractionOfDistanceBetweenInsertionPoints: nil
    )
    let attributes = textStorage.attributes(at: indexOfCharacter, effectiveRange: nil)
    let glyphIndex = textView.layoutManager.glyphIndex(
      for: pointInTextContainer, in: textView.textContainer)
    let lineFragmentRect = textView.layoutManager.lineFragmentRect(
      forGlyphAt: glyphIndex, effectiveRange: nil)
    let firstCharacterRect = textView.layoutManager.boundingRect(
      forGlyphRange: NSRange(location: glyphIndex, length: 1),
      in: textView.textContainer
    )

    for plugin in textView.editor.plugins {
      if let hit = plugin.hitTest?(
        at: pointInTextContainer,
        lineFragmentRect: lineFragmentRect,
        firstCharacterRect: firstCharacterRect,
        attributes: attributes
      ), hit {
        if let handled = plugin.handleTap?(
          at: pointInTextContainer,
          lineFragmentRect: lineFragmentRect,
          firstCharacterRect: firstCharacterRect,
          attributes: attributes
        ), handled {
          break
        }
      }
    }
  }
}
