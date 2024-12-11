/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation

extension String {
  public func lengthAsNSString() -> Int {
    let nsString = self as NSString
    return nsString.length
  }

  public func lengthAsNSString(excludingWhitespace: Bool) -> Int {
    let nsString = excludingWhitespace ? (self.filter { !$0.isWhitespace }) as NSString : self as NSString
    return nsString.length
  }
}
