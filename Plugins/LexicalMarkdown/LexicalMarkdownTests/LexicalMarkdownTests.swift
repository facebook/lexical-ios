/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

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

    XCTExpectFailure("Unimplemented")
  }
}

