// (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.

extension LexicalPlaygroundMainLaunchPointPlugins: PluginAppDelegateClassSocket {
  func function() -> AnyClass? {
    return AppDelegate.self
  }
}

extension LexicalPlaygroundAppMainPlugin: PluginAppMainSocket {
  func function(
    argc: CInt,
    argv: UnsafeMutablePointer<CChar>?,
    appClassName: String?,
    appDelegateClassName: String?
  ) -> CInt {
    AppDelegate.main()
    return 0
  }
}
