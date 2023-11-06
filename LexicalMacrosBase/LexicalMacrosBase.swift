import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum LexicalMacroError: Error, CustomStringConvertible {
  case requiresPrivate
  case requiresUnderscores
  case shouldBeClass
  case custom(String)

  var description: String {
    switch self {
    case .requiresPrivate:
      return "Nodes using the @Node macro should define all their properties as private"
    case .requiresUnderscores:
      return "Nodes using the @Node macro should define all their properties starting with an underscore"
    case .shouldBeClass:
      return "Should be applied to a class"
    case .custom(let s):
      return s
    }
  }
}

struct ParsedBinding {
  let name: String
  let publicName: String
  let capitalizedPublicName: String
  let type: String
}

public struct NodeMacro: MemberMacro {
  public static func expansion(
    of node: SwiftSyntax.AttributeSyntax,
    providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
    in context: some SwiftSyntaxMacros.MacroExpansionContext
  ) throws -> [SwiftSyntax.DeclSyntax] {
    guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
      throw LexicalMacroError.shouldBeClass
    }

    guard let arguments = node.argument?.as(TupleExprElementListSyntax.self) else {
      throw LexicalMacroError.custom("no arg list")
    }
    guard let firstArgument = arguments.first else {
      throw LexicalMacroError.custom("no arg")
    }
    guard let nodeType = firstArgument.expression.as(MemberAccessExprSyntax.self)?.name.text else {
      throw LexicalMacroError.custom("Must include a Lexical node type")
    }

    let vars = classDecl
      .memberBlock
      .members
      .compactMap { $0.decl.as(VariableDeclSyntax.self) }
      .filter { $0.bindings.filter { $0.accessor != nil } == [] }

    let nonPrivateVars = vars
      .filter { $0.modifiers?.compactMap{ $0.as(DeclModifierSyntax.self) }.compactMap{ $0.name.text == "private" }.isEmpty ?? true }
    if nonPrivateVars.count > 0 {
      throw LexicalMacroError.requiresPrivate
    }

    // each binding corresponds to one variable
    let bindings = vars.flatMap { $0.bindings }
      .map { binding in
        let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text ?? ""
        return ParsedBinding(name: name,
                             publicName: String(name.dropFirst()),
                             capitalizedPublicName: String(name.dropFirst()).capitalizedFirstLetter,
                             type: binding.typeAnnotation?.type.description ?? "")
      }

    var declarations: [DeclSyntax] = []

    declarations.append(typeMethod(nodeType))
    declarations.append(codingKeys(bindings))
    declarations.append(initWithoutKeyMethod(bindings))
    declarations.append(initWithKeyMethod(bindings))
    declarations.append(cloneMethod(bindings))
    declarations.append(encodeMethod(bindings))
    declarations.append(decodeMethod(bindings))

    for binding in bindings {
      if !binding.name.hasPrefix("_") {
        throw LexicalMacroError.requiresUnderscores
      }
      declarations.append(accessors(for: binding))
    }

    return declarations
  }

  static func accessors(for binding: ParsedBinding) -> DeclSyntax {
    return DeclSyntax("""
      public var \(raw: binding.publicName): \(raw: binding.type) {
        return getLatest().\(raw: binding.name)
      }

      public func get\(raw: binding.capitalizedPublicName)() -> \(raw: binding.type) {
        return getLatest().\(raw: binding.name)
      }

      public func set\(raw: binding.capitalizedPublicName)(_ val: \(raw: binding.type)) throws {
        try getWritable().\(raw: binding.name) = val
      }

      """)
  }

  private static func paramList(_ bindings: [ParsedBinding]) -> String {
    var builder = ""
    for (i, binding) in bindings.enumerated() {
      builder.append(binding.publicName)
      builder.append(": ")
      builder.append(binding.type)
      builder.append(i < bindings.count - 1 ? ", " : "")
    }
    return builder
  }

  private static func paramCall(_ bindings: [ParsedBinding]) -> String {
    var builder = ""
    for (i, binding) in bindings.enumerated() {
      builder.append(binding.publicName)
      builder.append(": ")
      builder.append(binding.publicName)
      builder.append(i < bindings.count - 1 ? ", " : "")
    }
    return builder
  }

  private static func paramCallPrivate(_ bindings: [ParsedBinding]) -> String {
    var builder = ""
    for (i, binding) in bindings.enumerated() {
      builder.append(binding.publicName)
      builder.append(": ")
      builder.append(binding.name)
      builder.append(i < bindings.count - 1 ? ", " : "")
    }
    return builder
  }

  static func initWithoutKeyMethod(_ bindings: [ParsedBinding] ) -> DeclSyntax {
    return DeclSyntax("""
    public convenience init(\(raw: paramList(bindings))) {
      self.init(\(raw: paramCall(bindings)), key: nil)
    }
    """)
  }

  static func initWithKeyMethod(_ bindings: [ParsedBinding] ) -> DeclSyntax {
    var builder = ""
    for binding in bindings {
      builder.append("self.\(binding.name) = \(binding.publicName)\n")
    }

    return DeclSyntax("""
    public required init(\(raw: paramList(bindings)), key: NodeKey?) {
      \(raw: builder)
      super.init(key)
    }
    """)
  }

  static func cloneMethod(_ bindings: [ParsedBinding] ) -> DeclSyntax {
    return DeclSyntax("""
    override public func clone() -> Self {
      Self(\(raw: paramCallPrivate(bindings)), key: key)
    }
    """)
  }

  static func codingKeys(_ bindings: [ParsedBinding] ) -> DeclSyntax {
    var items = ""
    for binding in bindings {
      items.append("case \(binding.publicName)\n")
    }

    return DeclSyntax("""
    enum CodingKeys: String, CodingKey {
    \(raw: items)
    }
    """)
  }

  static func encodeMethod(_ bindings: [ParsedBinding] ) -> DeclSyntax {
    var builder = ""
    for binding in bindings {
      builder.append("try container.encode(\(binding.name), forKey: .\(binding.publicName))\n")
    }

    return DeclSyntax("""
    override public func encode(to encoder: Encoder) throws {
      try super.encode(to: encoder)
      var container = encoder.container(keyedBy: CodingKeys.self)
      \(raw: builder)
    }
    """)
  }

  static func decodeMethod(_ bindings: [ParsedBinding] ) -> DeclSyntax {
    var builder = ""
    for binding in bindings {
      builder.append("self.\(binding.name) = try container.decode(\(binding.type).self, forKey: .\(binding.publicName))\n")
    }

    return DeclSyntax("""
    public required init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      \(raw: builder)
      try super.init(from: decoder)
    }
    """)
  }

  static func typeMethod(_ type: String ) -> DeclSyntax {
    return DeclSyntax("""
    open override class var type: NodeType {
      .\(raw: type)
    }
    """)
  }

}

@main
struct LexicalMacrosBase: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    NodeMacro.self,
  ]
}

extension String {
  var capitalizedFirstLetter: String {
    let firstLetter = self.prefix(1).capitalized
    let remainingLetters = self.dropFirst()
    return firstLetter + remainingLetters
  }
}
