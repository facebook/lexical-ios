// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation
@testable import Lexical
import XCTest

class UnknownNodeTests: XCTestCase {

  var textView: TextView?
  var editor: Editor? {
    get {
      return textView?.editor
    }
  }

  override func setUp() {
    textView = TextView()
  }

  override func tearDown() {
    textView = nil
  }

  func testCanEncodeAndDecodeAnyJson() throws {
    let simpleJson = """
{"id": "test-id","type": "a-random-string", "randomValue": [1, "2", true, false, { "3": 4.5 }, null]}
"""

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    guard let data = simpleJson.data(using: .utf8) else {
      XCTFail("No data created")
      return
    }

    let node = try decoder.decode(UnknownNode.self, from: data)

    let newData = try encoder.encode(node)

    let newNode = try decoder.decode(UnknownNode.self, from: newData)

    XCTAssertEqual(node.data, newNode.data, "Same data was not decoded in node constructors")
    XCTAssertEqual(node, newNode, "Node failed equality check from node constructors")
  }
}
