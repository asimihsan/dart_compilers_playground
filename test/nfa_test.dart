/*
 * ============================================================================
 *  Copyright 2020 Asim Ihsan. All rights reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License in the LICENSE file and at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 * ============================================================================
 */

import 'package:dart_compilers_playground/regex.dart';
import 'package:dart_compilers_playground/nfa.dart';
import 'package:test/test.dart';

void main() {
  test('test battery - regex is empty string', () {
    // input, regex, matcher
    var testCases = [
      ['a', '', false],
    ];
    executeTestCases(testCases);
  });

  test('test battery - just value', () {
    // input, regex, matcher
    var testCases = [
      ['a', 'a', true],
      ['a', 'b', false],
      ['', 'a', false],
    ];
    executeTestCases(testCases);
  });

  test('test battery - value and parentheses', () {
    // input, regex, matcher
    var testCases = [
      ['a', '(a)', true],
      ['a', '(b)', false],
      ['a', '((a))', true],
    ];
    executeTestCases(testCases);
  });

  test('test battery - value and concatenation', () {
    // input, regex, matcher
    var testCases = [
      ['aa', 'aa', true],
      ['ab', 'aa', false],
      ['aaaaaaa', 'aaaaaaa', true],
    ];
    executeTestCases(testCases);
  });

  test('test battery - value, concatenation, and parentheses', () {
    // input, regex, matcher
    var testCases = [
      ['aa', '(a)a', true],
      ['aa', 'a(a)', true],
      ['aa', '(aa)', true],
      ['ab', '(a)a', false],
    ];
    executeTestCases(testCases);
  });

  test('test battery - value and alternation', () {
    // input, regex, matcher
    var testCases = [
      ['a', 'a|b', true],
      ['c', 'a|b', false],
      ['e', 'a|b|c|d|e', true],
    ];
    executeTestCases(testCases);
  });

  test('test battery - value and closure', () {
    // input, regex, matcher
    var testCases = [
      ['a', 'a*', true],
      ['b', 'a*', false],
    ];
    executeTestCases(testCases);
  });

  test('test battery - value, concatenation, and closure', () {
    // input, regex, matcher
    var testCases = [
      ['a', 'aa*', true],
      ['b', 'ba*', true],
      ['b', 'ab*', false],
      ['b', 'bb*', true],
      ['a', 'aaa*', false],
      ['a', 'aa*a', false],
      ['a', 'a*aa', false],
    ];
    executeTestCases(testCases);
  });

  test('test battery - value, concatenation, closure, and parentheses', () {
    // input, regex, matcher
    var testCases = [
      ['a', '(a)a*', true],
      ['a', 'a(a)*', true],
      ['a', '(aa)*', false],
      ['a', 'a(aa)*', true],
      ['a', '(aa)*a', true],
      ['ab', '(ab)*(ab)*', true],
      ['ab', '(aa)*(ab)*(a)*a*', true],
    ];
    executeTestCases(testCases);
  });

  test('test battery - value and concatenation and alternation', () {
    // input, regex, matcher
    var testCases = [
      ['ab', 'ab|c', true],
      ['abc', 'ab|c', false],
      ['c', 'ab|c', true],
      ['b', 'ab|c', false],
    ];
    executeTestCases(testCases);
  });

  test('test battery - value, concatenation, closure, alternation, and parentheses', () {
    // input, regex, matcher
    var testCases = [
      ['a', '(a|b)*', true],
      ['b', '(a|b)*', true],
      ['a', '(a|b)*a', true],
      ['a', 'a(a|b)*', true],
      ['ab', '(a|b)*', true],
      ['ab', '(ab|bc)*', true],
      ['bc', '(ab|bc)*', true],
      ['bb', '(ab|bc)*', false],
    ];
    executeTestCases(testCases);
  });
}

void executeTestCases(final List<List<Object>> testCases) {
  for (var testCase in testCases) {
    var input = testCase[0] as String;
    var regex = testCase[1] as String;
    var expectedResult = testCase[2] as bool;
    print('input $input, regex $regex, expectedResult $expectedResult');
    executeTest(input, regex, expectedResult);
  }
}

void executeTest(final String input, final String regex, final bool expectedResult) {
  // === given ===
  var re = RegularExpression.fromString(regex);

  // === when ===
  var nfa = NFA.fromRegularExpression(re);

  // === then ===
  expect(nfa, isNotNull, reason: 'expected regex $regex to compile to non-null NFA');
  expect(nfa.matches(input), expectedResult,
      reason: 'expected regex $regex input $input to give result $expectedResult');
}
