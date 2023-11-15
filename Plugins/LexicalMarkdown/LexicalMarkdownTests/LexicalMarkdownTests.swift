//
//  LexicalMarkdownTests.swift
//
//
//  Created by mani on 15/11/2023.
//

import Foundation
@testable import Lexical
@testable import LexicalMarkdown
import XCTest

class LexicalMarkdownTests: XCTestCase {
  var lexicalView: LexicalView?
  var editor: Editor? {
    get {
      return lexicalView?.editor
    }
  }

  override func setUp() {
    lexicalView = LexicalView(editorConfig: EditorConfig(theme: Theme(), plugins: []), featureFlags: FeatureFlags())
  }

  override func tearDown() {
    lexicalView = nil
  }

  func testNodesToMarkdown() throws {
    guard let editor else { XCTFail(); return }

    XCTFail("Unimplemented")
  }
}

