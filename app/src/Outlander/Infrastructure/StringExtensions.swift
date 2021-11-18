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

    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }

    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }

    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        var indices: [Index] = []
        var startIndex = self.startIndex
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

    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
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
        let lowerSelf = trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines).lowercased()

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
        for c in self {
            if String(c) == delimiter, previous != "\\" {
                result.append(current.replacingOccurrences(of: "\\\(delimiter)", with: delimiter))
                current = ""
                continue
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
        let delimiter = "\""
        if !contains(delimiter) {
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
}
