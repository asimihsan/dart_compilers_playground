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

library regex;

import 'dart:collection';

import 'package:characters/characters.dart';
import 'package:quiver/core.dart';

enum RegularExpressionValueKind {
  // Empty string. Only occurs in NFAs.
  EPSILON,

  // A literal. Could be the result of a character class (e.g. \d) or inversion (e.g. [^"]).
  // TODO for now only a basic character literal is implemented.
  LITERAL,
}

// RegularExpressionValue is applied to edges of a NFA or DFA. They tell you whether an edge
// matches the current character or not in a string.
class RegularExpressionValue {
  final RegularExpressionValueKind _kind;
  final String _literal;

  const RegularExpressionValue.epsilon()
      : _kind = RegularExpressionValueKind.EPSILON,
        _literal = null;

  const RegularExpressionValue.literal(this._literal) : _kind = RegularExpressionValueKind.LITERAL;

  String get literal => _literal;

  RegularExpressionValueKind get kind => _kind;

  // Return the size of a match of an input at a given index.
  //
  // If no match return -1.
  // If an epsilon we always match and return 0 (nothing is consumed).
  // If a literal we check to see if we match and return the number of characters matched.
  int getMatchSize(final String input, final int inputIndex) {
    switch (_kind) {
      case RegularExpressionValueKind.EPSILON:
        return 0;

      case RegularExpressionValueKind.LITERAL:
        if (input.characters.isEmpty) {
          return -1;
        }
        if (inputIndex >= input.characters.length) {
          return -1;
        }
        var charToMatch = input.characters.elementAt(inputIndex);
        if (literal == charToMatch) {
          return literal.length;
        }
        return -1;
    }

    throw ArgumentError('could not determine match size for input $input inputIndex $inputIndex');
  }

  int get size => 1;

  @override
  String toString() {
    return 'RegularExpressionValue{_kind: $_kind, _literal: $_literal}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegularExpressionValue &&
          runtimeType == other.runtimeType &&
          _kind == other._kind &&
          _literal == other._literal;

  @override
  int get hashCode => _kind.hashCode ^ _literal.hashCode;
}

enum RegularExpressionKind { VALUE, CLOSURE, CONCATENATION, ALTERNATION }

// RegularExpression represents a tree of regular expression objects that terminate in VALUE's
// (characters). Maybe composed of other interior unary and binary RegularExpression's.
//
// Iterating from the root node in post-order gives you the correct initialization order for
// creating a non-deterministic finite automata (NFA). This class cannot be used directly
// to match a string against the regular expression.
//
// The tree encodes the precedence order of regular expression operators, from most important
// to least important:
//
// 1. Parentheses (most important), then
// 2. Closure, then
// 3. Concatenation, then
// 4. Alternation (least important)
//
// Parentheses are folded into the structure of the tree and have no explicit representation.
//
// TODO how do I escape from needing to use + as concatenation? a+ should be aa*.
//
// References
//
// [1] Engineering a Compiler 2nd Edition section 2.3 (Regular Expressions).
class RegularExpression {
  static final operandToPrecedence = {
    '(': 0,
    ')': 1,
    '*': 2,
    '+': 3,
    '|': 4,
  };
  static final operandToApplyFunction = {
    '*': applyClosureToOutput,
    '+': applyConcatenationToOutput,
    '|': applyAlternationToOutput,
  };

  final RegularExpressionKind _kind;
  final RegularExpression _left;
  final RegularExpression _right;
  final RegularExpressionValue _value;
  RegularExpression _parent;

  RegularExpression(this._kind, this._left, this._right, this._value);

  RegularExpression._ValueLiteral(final String value)
      : this(RegularExpressionKind.VALUE, null, null, RegularExpressionValue.literal(value));

  RegularExpression._Closure(final RegularExpression value)
      : this(RegularExpressionKind.CLOSURE, value, null, null);

  RegularExpression._Concatenation(final RegularExpression left, final RegularExpression right)
      : this(RegularExpressionKind.CONCATENATION, left, right, null);

  RegularExpression._Alternation(final RegularExpression left, final RegularExpression right)
      : this(RegularExpressionKind.ALTERNATION, left, right, null);

  // Create a tree of RegularExpression objects from an input String.
  //
  // Uses the shunting-yard algorithm [1] to convert the input infix expression into a
  // postfix expression, whilst simultaneous building up the regular expression tree.
  //
  // A post-order iteration over the resultant regular expression tree is required to create
  // an NFA.
  //
  // [1] https://en.wikipedia.org/wiki/Shunting-yard_algorithm
  factory RegularExpression.fromString(final String input) {
    final Queue<RegularExpression> output = ListQueue();
    final Queue<String> operands = ListQueue();

    var lookingAtValue = false;
    var lookingAtCloseParen = false;
    for (var character in input.characters) {
      switch (character) {
        case '(':
          if (lookingAtValue) {
            operands.addFirst('+');
          }
          operands.addFirst(character);
          lookingAtValue = false;
          lookingAtCloseParen = false;
          break;

        case ')':
          lookingAtValue = false;
          lookingAtCloseParen = true;
          var foundMatchingParen = false;
          while (operands.isNotEmpty && !foundMatchingParen) {
            var operand = operands.removeFirst();
            switch (operand) {
              case '*':
                applyClosureToOutput(output);
                break;
              case '|':
                applyAlternationToOutput(output);
                break;
              case '+':
                applyConcatenationToOutput(output);
                break;
              case '(':
                foundMatchingParen = true;
                break;
              default:
                throw StateError('unknown operand $operand found in operand stack');
            }
          }
          if (!foundMatchingParen) {
            throw StateError('was not able to balance parantheses');
          }

          break;

        case '*':
        case '|':
          final precedence = operandToPrecedence[character];
          while (operands.isNotEmpty) {
            final topOperand = operands.first;
            final topOperandPrecedence = operandToPrecedence[topOperand];
            final topOperandApplyFunction = operandToApplyFunction[topOperand];
            if (topOperandPrecedence > precedence || topOperandApplyFunction == null) {
              break;
            }
            operands.removeFirst();
            topOperandApplyFunction(output);
          }
          lookingAtValue = false;
          lookingAtCloseParen = false;

          if (character == '*') {
            applyClosureToOutput(output);
          } else {
            operands.addFirst(character);
          }
          break;

        default:
          if (lookingAtValue || lookingAtCloseParen) {
            operands.addFirst('+');
          }
          var value = RegularExpression._ValueLiteral(character);
          output.addFirst(value);
          lookingAtValue = true;
          lookingAtCloseParen = false;
          break;
      }
    }

    while (operands.isNotEmpty) {
      var operand = operands.removeFirst();
      switch (operand) {
        case '*':
          applyClosureToOutput(output);
          break;
        case '+':
          applyConcatenationToOutput(output);
          break;
        case '|':
          applyAlternationToOutput(output);
          break;
        default:
          throw StateError('unexpected operand $operand during final stage');
      }
    }

    while (output.length > 1) {
      applyConcatenationToOutput(output);
    }

    if (output.length != 1) {
      var actualLength = output.length;
      throw StateError('unexpected output length $actualLength at very end');
    }

    return output.removeFirst();
  }

  static void applyClosureToOutput(final Queue<RegularExpression> output) {
    var value = output.removeFirst();
    var newOutput = RegularExpression._Closure(value);
    value.parent = newOutput;
    output.addFirst(newOutput);
  }

  static void applyConcatenationToOutput(final Queue<RegularExpression> output) {
    var right = output.removeFirst();
    var left = output.removeFirst();
    var newOutput = RegularExpression._Concatenation(left, right);
    left.parent = newOutput;
    right.parent = newOutput;
    output.addFirst(newOutput);
  }

  static void applyAlternationToOutput(final Queue<RegularExpression> output) {
    var right = output.removeFirst();
    var left = output.removeFirst();
    var newOutput = RegularExpression._Alternation(left, right);
    left.parent = newOutput;
    right.parent = newOutput;
    output.addFirst(newOutput);
  }

  RegularExpressionKind get kind => _kind;

  RegularExpression get parent => _parent;

  set parent(final RegularExpression value) {
    _parent = value;
  }

  RegularExpression get left => _left;

  RegularExpression get right => _right;

  RegularExpressionValue get value => _value;

  @override
  String toString() {
    switch (kind) {
      case RegularExpressionKind.VALUE:
        return '{VALUE: $_value}';
      case RegularExpressionKind.CLOSURE:
        return '{CLOSURE ($left)}';
      case RegularExpressionKind.CONCATENATION:
        return '{CONCATENATION ($left, $right)}';
      case RegularExpressionKind.ALTERNATION:
        return '{ALTERNATION ($left, $right)}';
    }
    return '{ERROR UNKNOWN KIND}';
  }
}

// RegularExpressionPostOrderIterator lets you iterate over a RegularExpression tree
// in the correct order (post-order) to apply Thompson's construction to create
// NFA's in the correct order.
class RegularExpressionPostOrderIterator implements Iterator<RegularExpression> {
  final RegularExpression _root;
  RegularExpression _lastNodeVisited;
  bool isStarted = false;

  RegularExpressionPostOrderIterator(this._root);

  @override
  RegularExpression get current => _lastNodeVisited;

  @override
  bool moveNext() {
    if (!isStarted) {
      isStarted = true;
      _lastNodeVisited = _findLeftMostLeaf(_root);
      return true;
    }

    if (_lastNodeVisited == _root || _lastNodeVisited == null) {
      _lastNodeVisited = null;
      return false;
    }

    if (_isRightChild(_lastNodeVisited)) {
      _lastNodeVisited = _lastNodeVisited.parent;
      return true;
    }

    if (_hasRightSibling(_lastNodeVisited)) {
      _lastNodeVisited = _findLeftMostLeaf(_getRightSibling(_lastNodeVisited));
      return true;
    }

    _lastNodeVisited = _lastNodeVisited.parent;
    return true;
  }

  bool _isRightChild(final RegularExpression node) {
    return node.parent.right == node;
  }

  bool _hasRightSibling(final RegularExpression node) {
    return _getRightSibling(node) != null;
  }

  RegularExpression _getRightSibling(final RegularExpression node) {
    return node.parent.right;
  }

  RegularExpression _findLeftMostLeaf(final RegularExpression root) {
    var current = root;
    while (current.left != null) {
      current = current.left;
    }
    return current;
  }
}
