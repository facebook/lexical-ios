// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation

extension String {
  public func lengthAsNSString() -> Int {
    let nsString = self as NSString
    return nsString.length
  }
}
