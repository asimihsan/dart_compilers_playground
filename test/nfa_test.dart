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
  test('single character RE to NFA matches same single character', () {
    // === given ===
    var input = 'a';
    var re = RegularExpression.fromString(input);

    // === when ===
    var nfa = NFA.fromRegularExpression(re);

    // === then ===
    expect(nfa, isNotNull);
    expect(nfa.matches(input), isTrue);
  });

  test('single character RE to NFA does not match different single character', () {
    // === given ===
    var input = 'a';
    var re = RegularExpression.fromString(input);

    // === when ===
    var nfa = NFA.fromRegularExpression(re);

    // === then ===
    expect(nfa, isNotNull);
    expect(nfa.matches('b'), isFalse);
  });

  test('single character RE to NFA does not match different characters', () {
    // === given ===
    var input = 'a';
    var re = RegularExpression.fromString(input);

    // === when ===
    var nfa = NFA.fromRegularExpression(re);

    // === then ===
    expect(nfa, isNotNull);
    expect(nfa.matches('aa'), isFalse);
  });

  test('single character RE to NFA does not match empty string', () {
    // === given ===
    var input = 'a';
    var re = RegularExpression.fromString(input);

    // === when ===
    var nfa = NFA.fromRegularExpression(re);

    // === then ===
    expect(nfa, isNotNull);
    expect(nfa.matches(''), isFalse);
  });

  test('two character RE to NFA matches same two characters, characters are same', () {
    // === given ===
    var input = 'aa';
    var re = RegularExpression.fromString(input);

    // === when ===
    var nfa = NFA.fromRegularExpression(re);

    // === then ===
    expect(nfa, isNotNull);
    expect(nfa.matches(input), isTrue);
  });
}
