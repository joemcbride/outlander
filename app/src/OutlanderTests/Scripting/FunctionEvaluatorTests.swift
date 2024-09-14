//
//  FunctionEvaluatorTests.swift
//  OutlanderTests
//
//  Created by Joe McBride on 11/18/21.
//  Copyright © 2021 Joe McBride. All rights reserved.
//

import XCTest

class FunctionEvaluatorTests: XCTestCase {
    let evaluator = FunctionEvaluator(GameContext(InMemoryEvents())) { val in val }

    func test_evals_math() {
        let result = evaluator.evaluateValue(.value("2+2"))
        XCTAssertEqual(result.result, "4")
    }

    func test_evals_logic() {
        let result = evaluator.evaluateBool(.value("BARD == BARD && YES == YES"))
        XCTAssertEqual(result.result, "true")
    }

    func test_evals_logic_single_equals() {
        let result = evaluator.evaluateBool(.value("BARD = BARD && YES = YES"))
        XCTAssertEqual(result.result, "true")
    }
    
    func test_and_bool_vs_number_falsy() {
        let result = evaluator.evaluateBool(.value("0 && true"))
        XCTAssertEqual(result.result, "false")
    }

    func test_and_bool_vs_number_truthy() {
        let result = evaluator.evaluateBool(.value("1 && true"))
        XCTAssertEqual(result.result, "true")
    }
    
    func test_equals_number_vs_bool_falsy() {
        let result = evaluator.evaluateBool(.value("0 == true"))
        XCTAssertEqual(result.result, "false")
    }

    func test_equals_number_vs_bool_truthy() {
        let result = evaluator.evaluateBool(.value("1 == true"))
        XCTAssertEqual(result.result, "true")
    }

    func test_equals_bool_vs_number_falsy() {
        let result = evaluator.evaluateBool(.value("false == 1"))
        XCTAssertEqual(result.result, "false")
    }

    func test_equals_bool_vs_number_truthy() {
        let result = evaluator.evaluateBool(.value("true == 1"))
        XCTAssertEqual(result.result, "true")
    }

    func test_function_evaluations() {
    let cases = [
        (expr: "1 == 1.0", result: "true"),
        
        (expr: "TRUE == 1", result: "true"),
        (expr: "TRUE == TRUE", result: "true"),
        (expr: "TrUe == tRue", result: "true"),

        (expr: "true == 1", result: "true"),
        (expr: "true == 0", result: "false"),
        (expr: "true == -1", result: "false"),
        (expr: "false == 0", result: "true"),
        (expr: "false == 1", result: "false"),
        (expr: "false == 1.2", result: "false"),
        (expr: "true == 1.2", result: "false"),
        (expr: "false == what", result: "false"),

        (expr: "1 == true", result: "true"),
        (expr: "0 == true", result: "false"),
        (expr: "0 == false", result: "true"),
        (expr: "1 == false", result: "false"),
        (expr: "-1 == false", result: "false"),
        (expr: "1.2 == false", result: "false"),
        (expr: "1.2 == true", result: "false"),
        (expr: "what == false", result: "false"),

        (expr: "true && 1", result: "true"),
        (expr: "true && 0", result: "false"),
        (expr: "true && 1.2", result: "false"),
        (expr: "false && 0", result: "false"),
        (expr: "false && 1", result: "false"),
        (expr: "false && 1.2", result: "false"),
        (expr: "false && what", result: "false"),

        (expr: "1 && true", result: "true"),
        (expr: "0 && true", result: "false"),
        (expr: "-1 && true", result: "false"),
        (expr: "1.2 && true", result: "false"),
        (expr: "0 && false", result: "false"),
        (expr: "1 && false", result: "false"),
        (expr: "1.2 && false", result: "false"),
        (expr: "what && false", result: "false"),
        (expr: "what && 1", result: "false"),
        (expr: "what && 0", result: "false"),

        (expr: "true || 1", result: "true"),
        (expr: "true || 0", result: "true"),
        (expr: "true || 1.2", result: "true"),
        (expr: "false || 0", result: "false"),
        (expr: "false || 1", result: "true"),
        (expr: "false || -1", result: "false"),
        (expr: "false || 1.2", result: "false"),
        (expr: "false || -1.2", result: "false"),
        (expr: "false || what", result: "false"),
        (expr: "true || what", result: "true"),
        (expr: "1 || what", result: "true"),

        (expr: "1 || true", result: "true"),
        (expr: "0 || true", result: "true"),
        (expr: "1.2 || true", result: "true"),
        (expr: "-1.2 || true", result: "true"),
        (expr: "0 || false", result: "false"),
        (expr: "1 || false", result: "true"),
        (expr: "1.2 || false", result: "false"),
        (expr: "-1.2 || false", result: "false"),
        (expr: "what || false", result: "false"),
        (expr: "what || true", result: "true"),
        (expr: "what || 1", result: "true"),
    ]

        for (value, result) in cases {
            let exp = ScriptExpression.value(value)
            let named = "test '\(exp)' results in '\(result)'"
            let evalResult = evaluator.evaluateBool(exp)
            XCTAssertEqual(evalResult.result, result, named)
        }
    }

    // TODO: not sure if I want to try to support this - messes with regexes - can fix it now with parsing
//    func test_evals_logic_single_or() {
//        let result = evaluator.evaluateBool(.value("BARD = BARD | YES = NO"))
//        XCTAssertEqual(result.result, "true")
//    }
//
//    func test_evals_logic_single_and() {
//        let result = evaluator.evaluateBool(.value("BARD = BARD & YES = YES"))
//        XCTAssertEqual(result.result, "true")
//    }

    func test_evals_tolower_function() {
        let result = evaluator.evaluateStrValue(.function("tolower", ["ABCD"]))
        XCTAssertEqual(result.result, "abcd")
    }

    func test_evals_tolower_function_ignores_case() {
        let result = evaluator.evaluateStrValue(.function("ToLower", ["ABCD"]))
        XCTAssertEqual(result.result, "abcd")
    }

    func test_evals_startswith_function_success() {
        let result = evaluator.evaluateStrValue(.function("startswith", ["\"one two\"", "one"]))
        XCTAssertEqual(result.result, "true")
    }

    func test_evals_startswith_function_fail() {
        let result = evaluator.evaluateStrValue(.function("startswith", ["\"one two\"", "three"]))
        XCTAssertEqual(result.result, "false")
    }

    func test_evals_empty_value_to_false() {
        let expr: ScriptExpression = .value("")
        let result = evaluator.evaluateBool(expr)
        XCTAssertEqual(result.result, "false")
    }

    func test_evals_func() {
        let result = evaluator.evaluateStrValue(.values([.function("tolower", ["ONE"]), .value("== one")]))
        XCTAssertTrue(result.result.toBool() == true)
    }

    func test_evals_func_2() {
        let result = evaluator.evaluateBool(.values([.value("(3 == 4) || 2 ==  1 ||"), .function("tolower", ["ONE"]), .value("== one")]))
        XCTAssertTrue(result.result.toBool() == true)
    }

    func test_evals_func_name_ignores_case() {
        let result = evaluator.evaluateBool(.values([.function("ToLower", ["ONE"]), .value("== one")]))
        XCTAssertTrue(result.result.toBool() == true)
    }

    func test_contains_ignores_casing() {
        let result = evaluator.evaluateBool(.values([.function("contains", ["have ONE", "one"])]))
        XCTAssertTrue(result.result.toBool() == true)
    }

    func test_evals_func_with_leading_not() {
        let result = evaluator.evaluateBool(.values([.value("!"), .function("contains", ["have one", "one"])]))
        XCTAssertTrue(result.result.toBool() == false)
    }

    func test_evals_func_with_leading_double_not() {
        let result = evaluator.evaluateBool(.values([.value("!!"), .function("contains", ["have one", "one"])]))
        XCTAssertTrue(result.result.toBool() == true)
    }

    func test_evals_math_round() {
        let result = evaluator.evaluateValue(.function("round", ["5.5"]))
        XCTAssertEqual(result.result, "6")
    }

    func test_evals_math_ceil() {
        let result = evaluator.evaluateValue(.function("ceil", ["5.5"]))
        XCTAssertEqual(result.result, "6")
    }

    func test_evals_math_floor() {
        let result = evaluator.evaluateValue(.function("floor", ["5.5"]))
        XCTAssertEqual(result.result, "5")
    }

    func test_evals_substring() {
        let result = evaluator.evaluateValue(.function("substring", ["hello", "1", "2"]))
        XCTAssertEqual(result.result, "el")
    }

    func test_evals_substr() {
        let result = evaluator.evaluateValue(.function("substr", ["hello", "1", "2"]))
        XCTAssertEqual(result.result, "el")
    }

    func test_evals_substr_start_index_out_of_bounds() {
        let result = evaluator.evaluateValue(.function("substr", ["hello", "-1", "2"]))
        XCTAssertEqual(result.result, "substring start index is out of bounds")
    }

    func test_evals_substr_end_index_out_of_bounds() {
        let result = evaluator.evaluateValue(.function("substring", ["hello", "1", "6"]))
        XCTAssertEqual(result.result, "substring end index is out of bounds")
    }
}
