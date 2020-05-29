//
//  AliasCommandHandlerTests.swift
//  OutlanderTests
//
//  Created by Eitan Romanoff on 5/24/20.
//  Copyright © 2020 Joe McBride. All rights reserved.
//

import XCTest

class AliasCommandHandlerTests: XCTestCase {
    var handler = AliasCommandHandler()
    var context = GameContext()

    override func setUp() {}

    override func tearDown() {}

    func test_add() {
        let expectedAliasPattern = "corb"
        let expectedAliasReplace = "charge my camb orb 90"
        let expectedOtherAliasReplace = "charge my camb orb 89"
        let expectedAliasClass = "some class"
        let expectedAliasOtherClass = "some other class"

        let expectedFirstAliasValue = "#alias {\(expectedAliasPattern)} {\(expectedAliasReplace)} {\(expectedAliasClass)}"
        let expectedFirstAliasModifiedValue = "#alias {\(expectedAliasPattern)} {\(expectedOtherAliasReplace)} {\(expectedAliasClass)}"
        let expectedSecondAliasValue = "#alias {\(expectedAliasPattern)} {\(expectedOtherAliasReplace)} {\(expectedAliasOtherClass)}"

        // Test add
        context.gags = []
        handler.handle("#alias add {\(expectedAliasPattern)} {\(expectedAliasReplace)} {\(expectedAliasClass)}", with: context)

        var alias = context.aliases[0]
        XCTAssertEqual(context.aliases.count, 1)
        XCTAssertEqual(alias.pattern, expectedAliasPattern)
        XCTAssertEqual(alias.replace, expectedAliasReplace)
        XCTAssertEqual(alias.className, expectedAliasClass)
        XCTAssertEqual(alias.description, expectedFirstAliasValue)

        // Test update
        handler.handle("#alias add {\(expectedAliasPattern)} {\(expectedOtherAliasReplace)} {\(expectedAliasClass)}", with: context)

        alias = context.aliases[0]
        XCTAssertEqual(context.aliases.count, 1)
        XCTAssertEqual(alias.pattern, expectedAliasPattern)
        XCTAssertEqual(alias.replace, expectedOtherAliasReplace)
        XCTAssertEqual(alias.className, expectedAliasClass)
        XCTAssertEqual(alias.description, expectedFirstAliasModifiedValue)

        // Test add (different class)
        handler.handle("#alias add {\(expectedAliasPattern)} {\(expectedOtherAliasReplace)} {\(expectedAliasOtherClass)}", with: context)

        alias = context.aliases[1]
        XCTAssertEqual(context.aliases.count, 2)
        XCTAssertEqual(alias.pattern, expectedAliasPattern)
        XCTAssertEqual(alias.replace, expectedOtherAliasReplace)
        XCTAssertEqual(alias.className, expectedAliasOtherClass)
        XCTAssertEqual(alias.description, expectedSecondAliasValue)
    }

    func test_clear() {
        context.aliases = [Alias(pattern: "corb", replace: "charge my camb orb 90", className: "some class")]
        handler.handle("#alias clear", with: context)
        XCTAssertEqual(context.aliases.count, 0)
    }
}
