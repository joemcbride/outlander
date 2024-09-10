//
//  StringExtensions.swift
//
//
//  Created by Joseph McBride on 7/18/19.
//

import Foundation

extension String {
    subscript(i: Int) -> Character {
        self[index(startIndex, offsetBy: i)]
    }

    subscript(_ range: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: max(0, range.lowerBound))
        let end = index(start, offsetBy: min(count - range.lowerBound,
                                             range.upperBound - range.lowerBound))
        return String(self[start ..< end])
    }

    subscript(_ range: CountablePartialRangeFrom<Int>) -> String {
        let start = index(startIndex, offsetBy: max(0, range.lowerBound))
        return String(self[start...])
    }

    func index(of string: some StringProtocol, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }

    func endIndex(of string: some StringProtocol, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }

    func indices(of string: some StringProtocol, options: String.CompareOptions = []) -> [Index] {
        var indices: [Index] = []
        var startIndex = startIndex
        while startIndex < endIndex,
              let range = self[startIndex...]
              .range(of: string, options: options)
        {
            indices.append(range.lowerBound)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return indices
    }

    func ranges(of string: some StringProtocol, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = startIndex
        while startIndex < endIndex,
              let range = self[startIndex...]
              .range(of: string, options: options)
        {
            result.append(range)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }

    private static let trueValues = ["true", "yes", "1", "on", "+"]
    private static let falseValues = ["false", "no", "0", "off", "-"]

    func toBool() -> Bool? {
        let lowerSelf = trimmingCharacters(in: CharacterSet(["(", ")"])).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if String.trueValues.contains(lowerSelf) {
            return true
        }

        if String.falseValues.contains(lowerSelf) {
            return false
        }

        return nil
    }

    func commandsSeperated(by delimiter: String = ";") -> [String] {
        if !contains(delimiter) {
            return [self]
        }

        var result = [String]()
        var current = ""
        var previous = ""
        var inQuote = false
        for c in self {
            if String(c) == delimiter, previous != "\\", !inQuote {
                result.append(current.replacingOccurrences(of: "\\\(delimiter)", with: delimiter))
                current = ""
                continue
            }
            if c == "\"", previous != "\\" {
                inQuote = !inQuote
            }
            current += String(c)
            previous = String(c)
        }
        if current.count > 0 {
            result.append(current.replacingOccurrences(of: "\\\(delimiter)", with: delimiter))
        }
        return result
    }

    func argumentsSeperated() -> [String] {
        guard count > 0 else {
            return []
        }

        let delimiter = "\""
        guard contains(delimiter) else {
            return components(separatedBy: " ")
        }

        var result: [String] = []
        var current = ""
        var previous = ""
        var inArg = false
        for c in self {
            if String(c) == " ", inArg == false {
                if current.count > 0 {
                    result.append(current)
                }
                current = ""
                continue
            }

            if String(c) == delimiter, inArg == false, previous != "\\" {
                inArg = true
                continue
            }

            if String(c) == delimiter, inArg == true, previous != "\\" {
                inArg = false
                result.append("\"\(current)\"")
                current = ""
                continue
            }

            current += String(c)
            previous = String(c)
        }
        if inArg {
            current = "\"\(current)"
        }
        if current.count > 0 {
            result.append(current)
        }
        return result
    }

    func hasAnyPrefix(_ prefixes: [String]) -> Bool {
        for prefix in prefixes {
            if hasPrefix(prefix) {
                return true
            }
        }
        return false
    }

    func hasAnySuffix(_ suffixes: [String]) -> Bool {
        for suffix in suffixes {
            if hasSuffix(suffix) {
                return true
            }
        }
        return false
    }

    func trimLeadingWhitespace() -> String {
        guard let index = firstIndex(where: { !CharacterSet(charactersIn: String($0)).isSubset(of: .whitespaces) }) else {
            return self
        }
        return String(self[index...])
    }

    private static var valueFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = ""
        return formatter
    }()

    var formattedNumber: String? {
        guard let dbl = Double(self) else {
            return nil
        }
        let number = NSNumber(value: dbl)
        return Self.valueFormatter.string(from: number)!
    }

    func hexDecoededString() -> String {
        var newData = Data()
        var emojiStr = ""
        for char in replacingOccurrences(of: "\\\\x", with: "\\x").replacingOccurrences(of: "\\\\X", with: "\\X") {
            let str = String(char)
            if str == "\\" || str == "%" {
                emojiStr.append(str)
            } else if emojiStr == "\\" && str.lowercased() == "x" {
                emojiStr.append(str.lowercased())
            } else if emojiStr.hasPrefix("\\x") || emojiStr.hasPrefix("%") {
                emojiStr.append(str)
                if emojiStr.count == 4 || (emojiStr.count == 3 && emojiStr.hasPrefix("%")) {
                    // it can be a hex value
                    let value = emojiStr.replacingOccurrences(of: "\\x", with: "").replacingOccurrences(of: "%", with: "")
                    if let byte = UInt8(value, radix: 16) {
                        newData.append(byte)
                    } else {
                        newData.append(emojiStr.data(using: .utf8)!)
                    }
                    // reset emoji
                    emojiStr = ""
                }
            } else {
                // append the data as is
                if emojiStr.count > 0 {
                    newData.append(emojiStr.data(using: .utf8)!)
                    emojiStr = ""
                }
                newData.append(str.data(using: .utf8)!)
            }
        }

        let decodedString = String(data: newData, encoding: String.Encoding.utf8)
        return decodedString ?? ""
    }
}

extension CGFloat {
    private static var valueFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = ""
        return formatter
    }()

    var formattedNumber: String {
        let number = NSNumber(value: self)
        return Self.valueFormatter.string(from: number)!
    }
}

extension Double {
    private static var valueFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = ""
        return formatter
    }()

    var formattedNumber: String {
        let number = NSNumber(value: self)
        return Self.valueFormatter.string(from: number)!
    }
}
