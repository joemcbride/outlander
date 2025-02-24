//
//  FunctionEvaluator.swift
//  Outlander
//
//  Created by Joe McBride on 11/18/21.
//  Copyright © 2021 Joe McBride. All rights reserved.
//

import Foundation

struct EvalResult {
    var text: String
    var result: String
    var groups: [String]
}

class FunctionEvaluator {
    private let context: GameContext
    private let simplify: (String) -> String
    private let evaluator: ExpressionEvaluator

    init(_ context: GameContext, _ simplify: @escaping (String) -> String) {
        self.context = context
        self.simplify = simplify
        evaluator = ExpressionEvaluator()
    }

    func evaluateBool(_ e: ScriptExpression) -> EvalResult {
        switch e {
        case let .value(val):
            let simp = simplify(val)
            let result = evaluator.evaluateLogic(simp)
            return EvalResult(text: simp, result: "\(result)", groups: evaluator.groups)
        case let .function(name, args):
            let simpName = simplify(name)
            let simpArgs = args.map { simplify($0).trimmingCharacters(in: CharacterSet(["\""])) }
            do {
                let eval = FunctionExecutor(context)
                let result = try eval.execute(name: name, args: simpArgs)
                return EvalResult(text: "\(simpName)(\(simpArgs.map { "\"\($0)\"" }.joined(separator: ", ")))", result: result?.toBool() == true ? "true" : "false", groups: eval.groups)
            } catch {
                return EvalResult(text: simpName, result: "\(error)", groups: [])
            }
        case let .values(expressions):
            var groups: [String] = []
            let res: [String] = expressions.map {
                switch $0 {
                case let .value(txt):
                    return simplify(txt)
                case .values:
                    // TODO: yeah don't do this
                    return ""
                default:
                    let strRes = self.evaluateStrValue($0)
                    groups.append(contentsOf: strRes.groups)
                    return strRes.result
                }
            }
            let pretty = res.joined(separator: " ")
            let evaled = evaluateStrValue(.value(res.joined(separator: "")))
            groups.append(contentsOf: evaled.groups)
            return EvalResult(text: pretty, result: evaled.result, groups: groups)
        }
    }

    func evaluateStrValue(_ e: ScriptExpression) -> EvalResult {
        switch e {
        case let .value(val):
            let simp = simplify(val)
            if let result: Bool? = evaluator.evaluate(simp) {
                return EvalResult(text: simp, result: result == true ? "true" : "false", groups: evaluator.groups)
            }

            if let result: String? = evaluator.evaluate(simp) {
                return EvalResult(text: simp, result: result?.trimmingCharacters(in: CharacterSet(["\""])) ?? "", groups: evaluator.groups)
            }

            if let result: Double? = evaluator.evaluate(simp) {
                guard result?.isNaN != true, result?.isInfinite != true else {
                    return EvalResult(text: "'\(simp)' is infinite or not a number", result: "error", groups: evaluator.groups)
                }

                var res = "\((result ?? -1).formattedNumber)"

                if result == rint(result ?? -1) {
                    res = "\(Int(result ?? -1))"
                }
                return EvalResult(text: simp, result: res, groups: evaluator.groups)
            }

            return EvalResult(text: simp, result: "error", groups: [])
        case let .function(name, args):
            let simpName = simplify(name)
            let simpArgs = args.map { simplify($0).trimmingCharacters(in: CharacterSet(["\""])) }
            let eval = FunctionExecutor(context)
            do {
                let result = try eval.execute(name: name, args: simpArgs)
                return EvalResult(text: "\(simpName)(\(simpArgs.map { "\"\($0)\"" }.joined(separator: ", ")))", result: result ?? "", groups: eval.groups)
            } catch {
                return EvalResult(text: simpName, result: "\(error)", groups: [])
            }
        case let .values(expressions):
            var groups: [String] = []
            let res: [String] = expressions.map {
                switch $0 {
                case let .value(txt):
                    return txt
                case .values:
                    // TODO: yeah don't do this
                    return ""
                default:
                    let strRes = self.evaluateStrValue($0)
                    groups.append(contentsOf: strRes.groups)
                    return strRes.result
                }
            }
            let evaled = evaluateStrValue(.value(res.joined(separator: " ")))
            groups.append(contentsOf: evaled.groups)
            return EvalResult(text: evaled.text, result: evaled.result, groups: groups)
        }
    }

    func evaluateValue(_ e: ScriptExpression) -> EvalResult {
        switch e {
        case let .value(val):
            let simp = simplify(val)
            guard let result = evaluator.evaluateValue(simp) else {
                return EvalResult(text: simp, result: "0", groups: [])
            }

            var res = "\(result.formattedNumber)"

            if result == rint(result) {
                res = "\(Int(result))"
            }

            return EvalResult(text: simp, result: res, groups: evaluator.groups)
        case let .function(name, args):
            let simpName = simplify(name)
            let simpArgs = args.map { simplify($0).trimmingCharacters(in: CharacterSet(["\""])) }
            let eval = FunctionExecutor(context)
            do {
                let result = try eval.execute(name: name, args: simpArgs)
                return EvalResult(text: "\(simpName)(\(simpArgs.map { "\"\($0)\"" }.joined(separator: ", ")))", result: result ?? "", groups: eval.groups)
            } catch {
                return EvalResult(text: simpName, result: "\(error)", groups: [])
            }

        case let .values(expressions):
            var groups: [String] = []
            let res: [String] = expressions.map {
                switch $0 {
                case let .value(txt):
                    return txt
                case .values:
                    // TODO: yeah don't do this
                    return ""
                default:
                    let strRes = self.evaluateStrValue($0)
                    groups.append(contentsOf: strRes.groups)
                    return strRes.result
                }
            }
            let evaled = evaluateValue(.value(res.joined(separator: " ")))
            groups.append(contentsOf: evaled.groups)
            return EvalResult(text: evaled.text, result: evaled.result, groups: groups)
        }
    }
}

class FunctionExecutor {
    enum Symbol: Hashable {
        case function(String, arity: Int)
    }

    enum FunctionError: Error, CustomStringConvertible {
        case missing(String)
        case message(String)

        var description: String {
            switch self {
            case let .missing(message):
                return message
            case let .message(m):
                return m
            }
        }
    }

    public typealias SymbolEvaluator = (_ args: [String]) throws -> String

    private var functions: [Symbol: SymbolEvaluator] = [:]
    private var context: GameContext?

    var groups: [String] = []

    init(_ context: GameContext? = nil) {
        self.context = context

        func capitalize(args: [String]) -> String {
            let trimmed = trimQuotes(args[0])
            let start = trimmed.first?.uppercased() ?? ""
            let rest = trimmed.dropFirst().lowercased()
            return start + rest
        }

        func substring(_ args: [String]) throws -> String {
            let source = args[0]
            let start = Int(args[1]) ?? 0
            let end = Int(args[2]) ?? 0

            if start < 0 || start > source.count {
                throw FunctionError.message("substring start index is out of bounds")
            }

            if end < 0 || end < start || end > source.count {
                throw FunctionError.message("substring end index is out of bounds")
            }

            let startIdx = source.index(source.startIndex, offsetBy: start)
            let endIdx = source.index(source.startIndex, offsetBy: start + end)
            let range = startIdx ..< endIdx

            return String(source[range])
        }

        functions = [
            .function("contains", arity: 2): { args in
                let res = self.trimQuotes(args[0]).lowercased().contains(self.trimQuotes(args[1]).lowercased())
                return res ? "true" : "false"
            },
            .function("count", arity: 2): { args in
                let res = self.trimQuotes(args[0]).components(separatedBy: self.trimQuotes(args[1])).count - 1
                return "\(res)"
            },
            .function("countsplit", arity: 2): { args in
                let res = self.trimQuotes(args[0]).components(separatedBy: self.trimQuotes(args[1])).count
                return "\(res)"
            },
            .function("length", arity: 1): { args in
                "\(self.trimQuotes(args[0]).count)"
            },
            .function("len", arity: 1): { args in "\(self.trimQuotes(args[0]).count)" },
            .function("matchre", arity: 2): { args in
                var source = self.trimQuotes(args[0])
                let pattern = self.trimQuotes(args[1])
                guard let regex = RegexFactory.get(pattern) else {
                    return source
                }

                if let match = regex.firstMatch(&source) {
                    self.groups = match.values()
                    return match.count > 0 ? "true" : "false"
                }

                return "false"
            },
            .function("tolower", arity: 1): { args in self.trimQuotes(args[0]).lowercased() },
            .function("toupper", arity: 1): { args in self.trimQuotes(args[0]).uppercased() },
            .function("tocaps", arity: 1): { args in self.trimQuotes(args[0]).uppercased() },
            .function("trim", arity: 1): { args in self.trimQuotes(args[0]).trimmingCharacters(in: .whitespacesAndNewlines) },
            .function("replace", arity: 3): { args in
                let source = self.trimQuotes(args[0])
                let pattern = self.trimQuotes(args[1])
                let replacement = self.trimQuotes(args[2])
                let result = source.replacingOccurrences(of: pattern, with: replacement)
                return result
            },
            .function("replacere", arity: 3): { args in
                let source = self.trimQuotes(args[0])
                let pattern = self.trimQuotes(args[1])
                let replacement = self.trimQuotes(args[2])
                guard let regex = RegexFactory.get(pattern) else {
                    return source
                }
                let result = regex.replace(source, with: replacement)
                return result
            },
            .function("startswith", arity: 2): { args in
                self.trimQuotes(args[0]).hasPrefix(self.trimQuotes(args[1]))
                    ? "true" : "false"
            },
            .function("endswith", arity: 2): { args in self.trimQuotes(args[0]).hasSuffix(self.trimQuotes(args[1])) ? "true" : "false" },
            .function("capitalize", arity: 1): { args in capitalize(args: args) },
            .function("titlecase", arity: 1): { args in capitalize(args: args) },
            .function("floor", arity: 1): { args in
                let num = Double(args[0]) ?? 0
                let result = floor(num)

                var res = "\(result.formattedNumber)"

                if result == rint(result) {
                    res = "\(Int(result))"
                }

                return String(res)
            },
            .function("ceil", arity: 1): { args in
                let num = Double(args[0]) ?? 0
                let result = ceil(num)

                var res = "\(result.formattedNumber)"

                if result == rint(result) {
                    res = "\(Int(result))"
                }

                return String(res)
            },
            .function("def", arity: 1): { args in
                let variable = args[0]
                let result = context?.globalVars[variable] != nil ? true : false
                return String(result)
            },
            .function("round", arity: 1): { args in
                let num = Double(args[0]) ?? 0
                let result = round(num)

                var res = "\(result.formattedNumber)"

                if result == rint(result) {
                    res = "\(Int(result))"
                }

                return String(res)
            },
            .function("substring", arity: 3): { args in
                try substring(args)
            },
            .function("substr", arity: 3): { args in
                try substring(args)
            },
//            .function("percentencode", arity: 1): { args in
//                let text = self.trimQuotes(args[0])
//                if !text.isEmpty, let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
//                    return encoded
//                }
//                return ""
//            },
            .function("element", arity: 2): { args in
                let index = Int(self.trimQuotes(args[0]))
                let list = self.trimQuotes(args[1])
                if let idx = index, !list.isEmpty {
                    let items = list.components(separatedBy: "|")
                    if idx >= 0 && idx < items.count {
                        return items[idx]
                    }
                    return ""
                }
                return ""
            }
        ]
    }

    func execute(name: String, args: [String]) throws -> String? {
        let symbol: Symbol = .function(name.lowercased(), arity: args.count)
        guard let function = functions[symbol] else {
            throw FunctionError.missing("No function registered as \(symbol)")
        }
        return try function(args)
    }

    private func trimQuotes(_ input: String) -> String {
        input.trimmingCharacters(in: CharacterSet(["\""]))
    }
}
