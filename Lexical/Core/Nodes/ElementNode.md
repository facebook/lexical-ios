# ``Lexical/ElementNode``

A container node that can hold other nodes as children.

## Overview

`ElementNode` acts as the base class for all structural block and inline container nodes in Lexical iOS (such as `ParagraphNode`, `RootNode`, etc.). It extends `Node` and provides methods to traverse, modify, and query child nodes, text direction, and indentation.

## Topics

### Creating Element Nodes

- ``init()``
- ``init(_:)``

### Accessing Children

- ``getChildren()``
- ``getChildrenKeys()``
- ``getChildrenSize()``
- ``getChildAtIndex(index:)``
- ``getFirstChild()``
- ``getLastChild()``
- ``getFirstDescendant()``
- ``getLastDescendant()``
- ``getDescendantByIndex(index:)``
- ``isEmpty()``

### Modifying Children

- ``append(_:)``
- ``clear()``

### Indentation and Direction

- ``getIndent()``
- ``setIndent(_:)``
- ``canIndent()``
- ``getDirection()``
- ``setDirection(direction:)``

### Selection and Navigation

- ``select(anchorOffset:focusOffset:)``
- ``selectStart()``
- ``selectEnd()``

### Querying Node Properties

- ``isInline()``
- ``canBeEmpty()``
- ``canInsertTextBefore()``
- ``canInsertTextAfter()``
- ``canInsertAfter(node:)``
- ``canMergeWith(node:)``
- ``canReplaceWith(replacement:)``
- ``canExtractContents()``
- ``isShadowRoot()``

### Text Content Extraction

- ``getTextContent(includeInert:includeDirectionless:)``
- ``getAllTextNodes(includeInert:)``
- ``getPreamble()``
- ``getPostamble()``