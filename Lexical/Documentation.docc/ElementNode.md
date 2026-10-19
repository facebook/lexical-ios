# ``Lexical/ElementNode``

## Topics

### Initialization and serialization

- ``init()``
- ``init(_:)``
- ``init(from:)``
- ``encode(to:)``

### Children

- ``append(_:)``
- ``getChildren()``
- ``getChildrenKeys()``
- ``getChildrenSize()``
- ``getChildAtIndex(index:)``
- ``getFirstChild()``
- ``getLastChild()``
- ``isEmpty()``

### Descendants

- ``getDescendantByIndex(index:)``
- ``getFirstDescendant()``
- ``getLastDescendant()``
- ``getAllTextNodes(includeInert:)``

### Selection

- ``select(anchorOffset:focusOffset:)``
- ``selectStart()``
- ``selectEnd()``
- ``collapseAtStart(selection:)``

### Text output

- ``getPreamble()``
- ``getPostamble()``
- ``getTextPart()``
- ``getTextContent(includeInert:includeDirectionless:)``

### Layout behavior

- ``canIndent()``
- ``getIndent()``
- ``setIndent(_:)``
- ``isInline()``
- ``isShadowRoot()``

### Editing behavior

- ``insertNewAfter(selection:)``
- ``canBeEmpty()``
- ``canInsertTextBefore()``
- ``canInsertTextAfter()``
- ``canMergeWith(node:)``
- ``excludeFromCopy(destination:)``
- ``extractWithChild(child:selection:destination:)``
