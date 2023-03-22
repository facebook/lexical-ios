// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

import Foundation

public enum LexicalError: Error {
  case `internal`(String)
  case invariantViolation(String)
  case sanityCheck(errorMessage: String, textViewText: String, fullReconcileText: String)
  case reconciler(String)
  case rangeCacheSearch(String)
}
