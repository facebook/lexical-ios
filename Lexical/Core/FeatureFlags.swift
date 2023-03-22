// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation

@objc public class FeatureFlags: NSObject {
  let reconcilerSanityCheck: Bool
  let proxyTextViewInputDelegate: Bool

  @objc public init(reconcilerSanityCheck: Bool = false, proxyTextViewInputDelegate: Bool = false) {
    self.reconcilerSanityCheck = reconcilerSanityCheck
    self.proxyTextViewInputDelegate = proxyTextViewInputDelegate
    super.init()
  }
}
