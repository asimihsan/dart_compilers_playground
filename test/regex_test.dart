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
import 'package:test/test.dart';

void main() {
  test('can create new regular expression from single character', () {
    // === given ==
    var input = 'a';

    // === when ===
    var re = RegularExpression.fromString(input);

    // === then ===
    expect(re, isNotNull);
    expect(re.kind, RegularExpressionKind.VALUE);
    expect(re.value, isNotNull);
    expect(re.value.kind, RegularExpressionValueKind.LITERAL);
    expect(re.value.literal, input);
  });

  // a(b|c)*
  //
  // becomes

  /*


       +

     /   \
    /     \
   -       -

 a           *

             |
             |
             |

             |

           /   \
          /     \
         -       -

       b           c


   */
  test('can create new regular expression from more complex string', () {
    // === given ==
    var input = 'a(b|c)*';

    // === when ===
    var re = RegularExpression.fromString(input);

    // === then ===
    expect(re, isNotNull);
    expect(re.kind, RegularExpressionKind.CONCATENATION);
    expect(re.left, isNotNull);
    expect(re.left.kind, RegularExpressionKind.VALUE);
    expect(re.left.value, isNotNull);
    expect(re.left.value.kind, RegularExpressionValueKind.LITERAL);
    expect(re.left.value.literal, 'a');
    expect(re.right, isNotNull);
    expect(re.right.kind, RegularExpressionKind.CLOSURE);

    expect(re.right.left, isNotNull);
    expect(re.right.left.kind, RegularExpressionKind.ALTERNATION);

    expect(re.right.left.left, isNotNull);
    expect(re.right.left.left.kind, RegularExpressionKind.VALUE);
    expect(re.right.left.left.value, isNotNull);
    expect(re.right.left.left.value.kind, RegularExpressionValueKind.LITERAL);
    expect(re.right.left.left.value.literal, 'b');

    expect(re.right.left.right, isNotNull);
    expect(re.right.left.right.kind, RegularExpressionKind.VALUE);
    expect(re.right.left.right.value, isNotNull);
    expect(re.right.left.right.value.kind, RegularExpressionValueKind.LITERAL);
    expect(re.right.left.right.value.literal, 'c');
  });

  test('can iterate regular expression in post-order', () {
    // === given ===
    var input = 'a(b|c)*';
    var re = RegularExpression.fromString(input);

    // === when/then ===
    var iterator = RegularExpressionPostOrderIterator(re);
    expect(iterator.current, isNull);

    var move1 = iterator.moveNext();
    expect(move1, isTrue);
    var current1 = iterator.current;
    expect(current1.kind, RegularExpressionKind.VALUE);
    expect(current1.value.literal, 'a');

    var move2 = iterator.moveNext();
    expect(move2, isTrue);
    var current2 = iterator.current;
    expect(current2.kind, RegularExpressionKind.VALUE);
    expect(current2.value.literal, 'b');

    var move3 = iterator.moveNext();
    expect(move3, isTrue);
    var current3 = iterator.current;
    expect(current3.kind, RegularExpressionKind.VALUE);
    expect(current3.value.literal, 'c');

    var move4 = iterator.moveNext();
    expect(move4, isTrue);
    var current4 = iterator.current;
    expect(current4.kind, RegularExpressionKind.ALTERNATION);

    var move5 = iterator.moveNext();
    expect(move5, isTrue);
    var current5 = iterator.current;
    expect(current5.kind, RegularExpressionKind.CLOSURE);

    var move6 = iterator.moveNext();
    expect(move6, isTrue);
    var current6 = iterator.current;
    expect(current6.kind, RegularExpressionKind.CONCATENATION);

    var move7 = iterator.moveNext();
    expect(move7, isFalse);
    expect(iterator.current, isNull);

    // Redundant by checking we conform to the Iterator interface.
    var move8 = iterator.moveNext();
    expect(move8, isFalse);
    expect(iterator.current, isNull);
  });

  test('check post order iteration of aa', () {
    // === given ===
    var input = 'aa';
    var re = RegularExpression.fromString(input);

    // === when/then ===
    var iterator = RegularExpressionPostOrderIterator(re);
    expect(iterator.current, isNull);

    var move1 = iterator.moveNext();
    expect(move1, isTrue);
    var current1 = iterator.current;
    expect(current1.kind, RegularExpressionKind.VALUE);
    expect(current1.value.literal, 'a');

    var move2 = iterator.moveNext();
    expect(move2, isTrue);
    var current2 = iterator.current;
    expect(current2.kind, RegularExpressionKind.VALUE);
    expect(current2.value.literal, 'a');

    var move3 = iterator.moveNext();
    expect(move3, isTrue);
    var current3 = iterator.current;
    expect(current3.kind, RegularExpressionKind.CONCATENATION);

    var move4 = iterator.moveNext();
    expect(move4, isFalse);
    var current4 = iterator.current;
    expect(current4, isNull);
  });
}
