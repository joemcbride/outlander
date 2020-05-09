//
//  Regex.swift
//  Outlander
//
//  Created by Joseph McBride on 7/19/19.
//  Copyright © 2019 Joe McBride. All rights reserved.
//

import Foundation

class Regex {
    var pattern: String
    var expression: NSRegularExpression

    init(_ pattern: String, options: NSRegularExpression.Options = []) throws {
        self.pattern = pattern
        self.expression = try NSRegularExpression(pattern: pattern, options: options)
    }

    public func matches(_ input: String) -> [Range<String.Index>] {
        guard let result = self.expression.firstMatch(in: input, range: NSRange(location: 0, length: input.utf8.count)) else {
            return []
        }

        var ranges: [Range<String.Index>] = []
        
        for i in 0..<result.numberOfRanges {
            let range = result.range(at: i)
            if let rng = Range(range, in: input) {
                ranges.append(rng)
            }
        }

        return ranges
    }

    public func matches2(_ input: String) -> MatchResult? {
        guard let result = self.expression.firstMatch(in: input, range: NSRange(location: 0, length: input.utf8.count)) else {
            return nil
        }

        return MatchResult(input, result: result)
    }

    public func allMatches(_ input: String) -> [MatchResult] {
        let results = self.expression.matches(in: input, range: NSRange(location: 0, length: input.utf8.count))
        return results.map { res in
            return MatchResult(input, result: res)
        }
    }
}

class MatchResult {
    private let input: String
    private let result: NSTextCheckingResult
    
    init(_ input:String, result: NSTextCheckingResult) {
        self.input = input
        self.result = result
    }
    
    var count: Int {
        get {
            return self.result.numberOfRanges
        }
    }

    func valueAt(index: Int) -> String? {
        guard index < self.result.numberOfRanges else {
            return nil
        }
        
        let rangeIndex = self.result.range(at: index)
        if let range = Range(rangeIndex, in: self.input) {
            return String(self.input[range])
        }
        
        return nil
    }
}
