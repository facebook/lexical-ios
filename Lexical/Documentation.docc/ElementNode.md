# ``Lexical/ElementNode``

A node that owns an ordered list of child nodes.

Use ``ElementNode`` for block or inline containers: paragraphs, lists, quotes,
headings, the ``RootNode``, and custom nodes that nest other nodes. Leaf text
belongs on ``TextNode``; native views belong on ``DecoratorNode``.

## Topics

### Initialization and serialization

- ``init()``
- ``init(_:)``
- ``init(from:)``
- ``encode(to:)``

### Children

- ``getChildren()``
- ``getChildrenKeys()``
- ``getChildrenSize()``
- ``getChildAtIndex(index:)``
- ``getFirstChild()``
- ``getLastChild()``
- ``getFirstDescendant()``
- ``getLastDescendant()``
- ``getDescendantByIndex(index:)``
- ``getAllTextNodes(includeInert:)``
- ``isEmpty()``

### Inserting and removing children

- ``append(_:)``
- ``clear()``
- ``insertNewAfter(selection:)``

### Selection

- ``select(anchorOffset:focusOffset:)``
- ``selectStart()``
- ``selectEnd()``

### Indent

- ``getIndent()``
- ``setIndent(_:)``
- ``canIndent()``

### Layout and merge heuristics

- ``isInline()``
- ``canBeEmpty()``
- ``canInsertTextBefore()``
- ``canInsertTextAfter()``
- ``canInsertTab()``
- ``canInsertAfter(node:)``
- ``canReplaceWith(replacement:)``
- ``canExtractContents()``
- ``canSelectionRemove()``
- ``canMergeWith(node:)``
- ``collapseAtStart(selection:)``
- ``excludeFromCopy(destination:)``
- ``extractWithChild(child:selection:destination:)``
- ``isShadowRoot()``

### Text output

- ``getTextPart()``
- ``getPreamble()``
- ``getPostamble()``
- ``getTextContent(includeInert:includeDirectionless:)``
