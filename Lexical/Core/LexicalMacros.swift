//
//  File.swift
//  
//
//  Created by Amy Worrall on 18/07/2023.
//

import Foundation

@attached(member, names: arbitrary)
public macro LexicalNode(_ type: NodeType) = #externalMacro(module: "LexicalMacrosBase", type: "NodeMacro")
