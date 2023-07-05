# Changelog

This document lists changes made in each released version of Lexical.

## 0.1 (Wed 5th July 2023)

- Initial release
- Features
  - Lexical API re-implemented in Swift
  - ``LexicalView``, a rich text editor for use within UIKit
  - An example Playground app, containing a sample implementation of a rich text toolbar
  - JSON serialization
  - HTML export (work in progress)
  - Decorator node API allows embedding inline `UIView`s that move with the text
  - Embedded inline images
  - Bulleted and numbered lists
  - Theming support based on NSAttributedString attributes
  - Plugin interface, including commands, listeners, and custom drawing routines
  - A read-only Lexical renderer ``LexicalReadOnlyView`` (currently undocumented)
  - Initial read-only support for tables

- A note on API stability
  - For versions before we hit `1.0`, any breaking changes of the API will be accompanied by an increase in the second version digit. For example, a `0.1.1` release will not contain breaking API changes (although it may contain API additions); whereas a `0.2` release may contain breaking changes. We will attempt to mention any such changes in the release notes. 
