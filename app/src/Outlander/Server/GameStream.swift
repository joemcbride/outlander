//
//  Tokenizer.swift
//  Outlander
//
//  Created by Joseph McBride on 7/29/19.
//  Copyright © 2019 Joe McBride. All rights reserved.
//

import Foundation

struct Attribute {
    var key: String
    var value: String
}

enum StreamToken {
    indirect case tag(name: String, attributes: [Attribute], children: [StreamToken])
    case text(String)
}

extension StreamToken {
    func name() -> String? {
        switch self {
        case let .text(text): return text == "\n" ? "eot" : "text"
        case let .tag(name, _, _):
            return name
        }
    }

    func hasAttr(_ key: String) -> Bool {
        return attr(key) != nil
    }

    func attr(_ key: String) -> String? {
        switch self {
        case .text: return nil
        case let .tag(_, attrs, _):
            for attr in attrs {
                if attr.key == key {
                    return attr.value
                }
            }
            return nil
        }
    }

    func value(_ separator: String = ",") -> String? {
        switch self {
        case let .text(text): return text
        case let .tag(_, _, children):
            return children.compactMap { $0.value() }.joined(separator: separator)
        }
    }

    func children() -> [StreamToken] {
        switch self {
        case .text: return []
        case let .tag(_, _, children):
            return children
        }
    }

    func monsters(_ ignore: Regex? = nil) -> [StreamToken] {
        switch self {
        case .text: return []
        case let .tag(_, _, children):
            return filterBetweenTags(children, start: "pushbold", end: "popbold", ignore: ignore)
        }
    }

    func filterBetweenTags(_ tokens: [StreamToken], start: String, end: String, ignore: Regex?) -> [StreamToken] {
        guard tokens.count > 0 else {
            return []
        }

        var results: [StreamToken] = []
        var capture = false

        for item in tokens {
            if item.name()?.lowercased() == start {
                capture = true
                continue
            } else if item.name()?.lowercased() == end {
                capture = false
                continue
            }

            let match = ignore?.hasMatches(item.value() ?? "") ?? false

            if capture, !match {
                results.append(item)
            }
        }

        return results
    }
}

protocol IReaderMode: class {
    func read(_ context: StreamContext) -> IReaderMode?
}

class ReaderBase<T> {
    private var modes: Stack<IReaderMode>

    init(target: T) {
        modes = Stack<IReaderMode>()
        self.target = target
    }

    public var target: T

    var current: IReaderMode? { return modes.peek() }

    public func push(_ mode: IReaderMode) {
        modes.push(mode)
    }

    public func read(_ text: String) -> [StreamToken] {
        guard modes.hasItems() else { return [] }

        let context = StreamContext([], text: text[...])

        startNewMode(context)

        push(TextMode())

        return context.target
    }

    func startNewMode(_ context: StreamContext) {
        guard modes.hasItems() else { return }

        let next = current?.read(context)

        guard let nextMode = next else {
            _ = modes.pop()
            startNewMode(context)
            return
        }

        if nextMode !== current {
            modes.push(nextMode)
            startNewMode(context)
        }
    }
}

class GameStreamTokenizer: ReaderBase<[StreamToken]> {
    init() {
        super.init(target: [])
        push(TextMode())
    }
}

class StreamContext {
    var text: String.SubSequence
    var target: [StreamToken]

    init(_ target: [StreamToken], text: String.SubSequence) {
        self.target = target
        self.text = text
    }
}

class TextMode: IReaderMode {
    func read(_ context: StreamContext) -> IReaderMode? {
        let result = context.text.parseMany(while: { $0 != "<" })
        if result.count > 0 {
            context.target.append(StreamToken.text(String(result)))
        }

        guard context.text.first != nil else {
            return nil
        }

        return TagMode()
    }
}

class TagMode: IReaderMode {
    var tagName: String = ""
    var children: [StreamToken] = []
    var attributes: [Attribute] = []

    func read(_ context: StreamContext) -> IReaderMode? {
        context.text.consume(expecting: "<")

        let result = context.text.parseMany(while: { $0 != "/" && $0 != ">" && $0 != " " })
        tagName = String(result).lowercased()

        return readNext(context)
    }

    func readNext(_ context: StreamContext) -> IReaderMode? {
        guard let f = context.text.first else { return nil }

        switch f {
        case "/":
            context.text.consume(expecting: "/")
            guard let f2 = context.text.first, f2 != ">" else {
                // consume self closing tag
                context.text.consume(expecting: ">")
                appendTag(context)
                return nil
            }

            return nil

        case ">":
            context.text.consume(expecting: ">")
            children = readChildren(context)
            appendTag(context)
            return nil
        case " ":
            attributes = context.text.parseAttributes(tagName)
            return readNext(context)
        default:
            return nil
        }
    }

    func readChildren(_ context: StreamContext) -> [StreamToken] {
        let childContext = StreamContext([], text: context.text)

        _ = TextMode().read(childContext)

        while !isClosingTagNext(childContext) {
            _ = TagMode().read(childContext)
            _ = TextMode().read(childContext)
        }

        context.text = childContext.text

        consumeClosingTag(context)

        return childContext.target
    }

    func consumeClosingTag(_ context: StreamContext) {
        context.text.consume(while: { $0 != ">" })
        context.text.consume(expecting: ">")
    }

    func isClosingTagNext(_ context: StreamContext) -> Bool {
        if let first = context.text.first,
            let second = context.text.second,
            first == "<", second == "/" {
            return true
        }
        return false
    }

    func appendTag(_ context: StreamContext) {
        context.target.append(StreamToken.tag(name: tagName, attributes: attributes, children: children))
    }
}

protocol StringView: Collection {
    static func string(_ elements: [Element]) -> String

    static var newline: Element { get }
    static var carriageReturn: Element { get }
    static var space: Element { get }
    static var quote: Element { get }
    static var tick: Element { get }
    static var backslash: Element { get }
    static var forwardslash: Element { get }
    static var equal: Element { get }
    static var rightBracket: Element { get }
    static var greaterThan: Element { get }
    static var lessThan: Element { get }
}

extension Substring: StringView {
    static func string(_ elements: [Character]) -> String {
        return String(elements)
    }

    static let newline: Character = "\n"
    static let carriageReturn: Character = "\r"
    static let space: Character = " "
    static let quote: Character = "\""
    static let tick: Character = "'"
    static let backslash: Character = "\\"
    static let forwardslash: Character = "/"
    static let equal: Character = "="
    static let rightBracket: Character = "]"
    static let greaterThan: Character = ">"
    static let lessThan: Character = "<"
}

extension StringView where SubSequence == Self, Element: Equatable {
    var second: Element? {
        let idx = self.index(after: self.startIndex)
        return self[idx]
    }

    mutating func consume(expecting char: Element) {
        guard let f = first, f == char else { return }
        removeFirst()
    }

    mutating func consume(while cond: (Element) -> Bool) {
        while let f = first, cond(f) {
            removeFirst()
        }
    }

    mutating func parseMany(while cond: (Element) -> Bool) -> [Element] {
        var result: [Element] = []
        while let c = first, cond(c) {
            result.append(c)
            removeFirst()
        }
        return result
    }

    mutating func parseMany<A>(_ f: (inout Self) -> A?, while cond: (Element) -> Bool) -> [A] {
        var result: [A] = []
        while let c = first, cond(c), let next = f(&self) {
            result.append(next)
        }
        return result
    }

    mutating func parseAttribute(_ tagName: String? = nil) -> Attribute? {
        let key = Self.string(parseMany(while: { $0 != Self.equal }))

        guard key.count > 0 else { return nil }

        consume(expecting: Self.equal)
        guard let delimiter = popFirst() else { return nil }

        var value: [Element]

        if key == "subtitle", tagName == "streamwindow" {
            value = parseMany({ $0.parseQuotedCharacter() }, while: { $0 != Self.rightBracket })
            value.append(Self.rightBracket)
            consume(expecting: Self.rightBracket)
        } else {
            value = parseMany({ $0.parseQuotedCharacter() }, while: { $0 != delimiter })
        }

        consume(expecting: delimiter)

        return Attribute(key: key, value: Self.string(value))
    }

    mutating func parseAttributes(_ tagName: String? = nil) -> [Attribute] {
        var attributes: [Attribute] = []

        consume(while: { $0 == Self.space })

        while let f = first, f != Self.greaterThan, f != Self.forwardslash {
            if let attr = parseAttribute(tagName) {
                attributes.append(attr)
            }
            consume(while: { $0 == Self.space })
        }

        return attributes
    }

    mutating func parseQuotedCharacter() -> Element? {
        guard let c = popFirst() else { return nil }

        switch c {
        case Self.backslash:
            return popFirst()
        case Self.carriageReturn:
            return popFirst()
        default:
            return c
        }
    }
}

struct TextTag {
    var text: String
    var window: String
    var color: String?
    var backgroundColor: String?
    var href: String?
    var command: String?
    var mono: Bool = false
    var bold: Bool = false
    var isPrompt: Bool = false
    var preset: String?
    var playerCommand: Bool = false

    func canCombineWith(_ tag: TextTag) -> Bool {
        guard window == tag.window else { return false }
        guard isPrompt == tag.isPrompt else { return false }
        guard mono == tag.mono else { return false }
        guard bold == tag.bold else { return false }
        guard preset == tag.preset else { return false }
        guard color == tag.color else { return false }
        guard backgroundColor == tag.backgroundColor else { return false }
        guard href == tag.href else { return false }
        guard command == tag.command else { return false }
        guard playerCommand == tag.playerCommand else { return false }

        return true
    }

    func combine(_ tag: TextTag) -> [TextTag] {
        guard canCombineWith(tag) else { return [self, tag] }

        return [TextTag(
            text: text + tag.text,
            window: window,
            color: color,
            backgroundColor: backgroundColor,
            href: href,
            command: command,
            mono: mono,
            bold: bold,
            preset: preset
        )]
    }

    static func tagFor(_ text: String, window: String = "", mono: Bool = false, preset: String? = nil) -> TextTag {
        return TextTag(text: text, window: window, mono: mono, preset: preset)
    }

    static func combine(tags: [TextTag]) -> [TextTag] {
        let start: [TextTag] = []

        let combined = tags.reduce(start) { list, next in

            if let last = list.last {
                return list.dropLast() + last.combine(next)
            }

            return [next]
        }

        return combined
    }
}

enum StreamCommand: CustomStringConvertible {
    case text([TextTag])
    case clearStream(String)
    case createWindow(name: String, title: String, ifClosed: String)
    case vitals(name: String, value: Int)
    case launchUrl(String)
    case spell(String)
    case roundtime(Date)
    case room
    case compass([String: String])
    case hands(String, String)
    case character(String, String)

    var description: String {
        switch self {
        case .text:
            return "text"
        default:
            return "other"
        }
    }
}

class GameStream {
    var tokenizer: GameStreamTokenizer
    var context: GameContext

    private var isSetup = false
    private var inStream = false
    private var lastStreamId = ""
    private var ignoreNextEot = false

    private var mono = false
    private var bold = false

    private var lastToken: StreamToken?

    private var streamCommands: (StreamCommand) -> Void

    private var tags: [TextTag] = []

    private let ignoredEot = [
        "app",
        "clearstream",
        "compass",
        "compdef",
        "component",
        "dialogdata",
        "endsetup",
        "exposecontainer",
        "indicator",
        "left",
        "mode",
        "opendialog",
        "nav",
        "output",
        "right",
        "streamwindow",
        "spell",
        "switchquickbar",
    ]

    private let ignoreNextEotList = [
        "experience",
        "inv",
        "popstream",
        "room",
    ]

    private let roomTags = [
        "roomdesc",
        "roomobjs",
        "roomplayers",
        "roomexits",
        "roomextra",
    ]

    private let compassMap = [
        "n": "north",
        "s": "south",
        "e": "east",
        "w": "west",
        "ne": "northeast",
        "nw": "northwest",
        "se": "southeast",
        "sw": "southwest",
        "up": "up",
        "down": "down",
        "out": "out",
    ]

    var monsterCountIgnoreList: String = "" {
        didSet {
            self.monsterCountIgnoreRegex = try? Regex(self.monsterCountIgnoreList)
        }
    }

    var monsterCountIgnoreRegex: Regex?

    init(context: GameContext, streamCommands: @escaping (StreamCommand) -> Void) {
        self.context = context
        self.streamCommands = streamCommands
        tokenizer = GameStreamTokenizer()
    }

    public func resetSetup(_ isSetup: Bool = false) {
        self.isSetup = isSetup
    }

    public func stream(_ data: Data) {
        stream(String(data: data, encoding: .utf8) ?? "")
    }

    public func stream(_ data: String) {
        let tokens = tokenizer.read(data.replacingOccurrences(of: "\r\n", with: "\n"))

        for token in tokens {
            processToken(token)

            if let tag = tagForToken(token) {
                let isPrompt = token.name() == "prompt"

                if isPrompt && tags.count == 0 { return }

                tags.append(tag)

                if !isSetup || isPrompt {
                    streamCommands(.text(TextTag.combine(tags: tags)))
                    tags.removeAll()
                }
            }
        }
    }

    func processToken(_ token: StreamToken) {
        guard case let .tag(tagName, _, children) = token else { return }

        switch tagName {
        case "prompt":
            context.globalVars["prompt"] = token.value()?.replacingOccurrences(of: "&gt;", with: ">") ?? ""
            context.globalVars["gametime"] = token.attr("time") ?? ""

            let today = Date().timeIntervalSince1970
            context.globalVars["gametimeupdate"] = "\(today)"

        case "roundtime":
            if let num = Int(token.attr("value") ?? "") {
                let rt = Date(timeIntervalSince1970: TimeInterval(num))
                streamCommands(.roundtime(rt))
            }

        case "left":
            context.globalVars["lefthand"] = token.value() ?? "Empty"
            context.globalVars["lefthandnoun"] = token.attr("noun") ?? ""

            streamCommands(.hands(
                context.globalVars["lefthand"] ?? "Empty",
                context.globalVars["righthand"] ?? "Empty"
            ))

        case "right":
            context.globalVars["righthand"] = token.value() ?? "Empty"
            context.globalVars["righthandnoun"] = token.attr("noun") ?? ""

            streamCommands(.hands(
                context.globalVars["lefthand"] ?? "Empty",
                context.globalVars["righthand"] ?? "Empty"
            ))

        case "spell":
            if let spell = token.value() {
                context.globalVars["preparedspell"] = spell
                streamCommands(.spell(spell))
            }

        case "pushbold":
            bold = true

        case "popbold":
            bold = false

        case "clearstream":
            if let id = token.attr("id") {
                streamCommands(.clearStream(id.lowercased()))
            }

        case "pushstream":
            inStream = true
            if let id = token.attr("id") {
                lastStreamId = id.lowercased()
            }

        case "popstream":
            ignoreNextEot = ignoreNextEotList.contains(lastStreamId)
            inStream = false
            lastStreamId = ""

        case "streamwindow":
            let id = token.attr("id")
            let subtitle = token.attr("subtitle")

            if id == "main", subtitle != nil, subtitle!.count > 3 {
                context.globalVars["roomtitle"] = String(subtitle!.dropFirst(3))
            }

            if !isSetup, let win = id {
                streamCommands(.createWindow(name: win, title: token.attr("title") ?? "", ifClosed: token.attr("ifClosed") ?? ""))
            }

        case "component":
            guard var id = token.attr("id") else { return }

            if !id.hasPrefix("exp") {
                id = id.replacingOccurrences(of: " ", with: "")

                let value = token.value("") ?? ""
                context.globalVars[id] = value

                if id == "roomobjs" {
                    let monsters = token.monsters(monsterCountIgnoreRegex)
                    context.globalVars["monsterlist"] = monsters.map { t in t.value() ?? "" }.joined(separator: "|")
                    context.globalVars["monstercount"] = "\(monsters.count)"
                }

                if roomTags.contains(id) {
                    streamCommands(.room)
                }
            }

        case "compass":
            let directions = token.children().filter { $0.name() == "dir" && $0.hasAttr("value") }

            var found: [String] = []
            var settings: [String: String] = [:]

            for dir in directions {
                let mapped = compassMap[dir.attr("value")!]!
                found.append(mapped)
                settings[mapped] = "1"
            }

            let notFound = compassMap.values.filter { !found.contains($0) }

            for dir in notFound {
                settings[dir] = "0"
            }

            for (key, value) in settings {
                context.globalVars[key] = value
            }

            streamCommands(.compass(settings))

        case "indicator":
            let id = token.attr("id")?.dropFirst(4).lowercased() ?? ""
            let visible = token.attr("visible") == "y" ? "1" : "0"

            guard id.count > 0 else { break }

            context.globalVars[id] = visible

        case "dialogdata":
            let vitals = children.filter { $0.name() == "progressbar" && $0.hasAttr("id") }

            for vital in vitals {
                let name = vital.attr("id") ?? ""
                let value = vital.attr("value") ?? "0"

                context.globalVars[name] = value
                streamCommands(.vitals(name: name, value: Int(value)!))
            }

        case "app":
            let characterName = token.attr("char") ?? ""
            let game = token.attr("game") ?? ""
            context.globalVars["charactername"] = characterName
            context.globalVars["game"] = game
            streamCommands(.character(game, characterName))

        case "launchurl":
            if let url = token.attr("src") {
                streamCommands(.launchUrl(url))
            }

        case "endsetup":
            isSetup = true

        default:
            return
        }
    }

    func tagForToken(_ token: StreamToken) -> TextTag? {
        var tag: TextTag?

        switch token.name() {
        case "text":
            tag = createTag(token)
            tag?.window = lastStreamId

            if inStream, lastStreamId == "logons" || lastStreamId == "death" {
                let trimmed = tag?.text.trimmingCharacters(in: CharacterSet.whitespaces) ?? ""
                tag?.text = trimmed
            }

            if lastToken?.name() == "preset", tag!.text.count > 0, tag!.text.hasPrefix("  You also see") {
                tag?.preset = lastToken?.attr("id")
                let text = "\n\(tag!.text.dropFirst(2))"
                tag?.text = text
            }

            if lastToken?.name() == "style", lastToken?.attr("id") == "roomName" {
                tag?.preset = "roomname"
            }

        case "eot":
            guard let tokenName = lastToken?.name(), !self.ignoredEot.contains(tokenName) else {
                break
            }
            guard !inStream else { break }
            guard tokenName != "prompt" else { break }

            guard !ignoreNextEot else {
                ignoreNextEot = false
                break
            }

            tag = TextTag(text: "\n", window: "")

        case "prompt":
            tag = createTag(token)
            tag?.isPrompt = true

        case "output":
            if let style = token.attr("class") {
                if style == "mono" {
                    mono = true
                } else {
                    mono = false
                }
            }

        case "a":
            tag = createTag(token)
            tag?.href = token.attr("href")

            if inStream {
                tag?.window = lastStreamId
            }

        case "b":
            // <b>You yell,</b> Hogs!
            tag = createTag(token)

            if inStream {
                tag?.bold = true
                tag?.window = lastStreamId
            }

        case "d":
            guard case let .tag(_, _, children) = token else { break }

            if children.count > 0 {
                if children[0].name() == "b" || children[0].name() == "text" {
                    tag = createTag(children[0])
                }

            } else {
                tag = createTag(token)
            }

            if let cmd = token.attr("cmd") {
                tag?.command = cmd
            }

            if inStream {
                tag?.window = lastStreamId
            }

        case "preset":
            tag = createTag(token)
            tag?.window = lastStreamId
            tag?.preset = token.attr("id")?.lowercased()

        default:
            tag = nil
        }

        lastToken = token

        return tag
    }

    func createTag(_ token: StreamToken) -> TextTag {
        var text = token.value() ?? ""
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&amp;", with: "&")

        var tag: TextTag = TextTag.tagFor(text)

        tag.bold = bold
        tag.mono = mono

        return tag
    }
}
