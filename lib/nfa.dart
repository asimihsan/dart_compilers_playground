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

library nfa;

import 'dart:collection';

import 'package:dart_compilers_playground/regex.dart';

// NFA is a non-deterministic finite automata (NFA) that allows you to match a regular expression.
//
// The intended use case is to start with a RegularExpression tree. NFA then uses
// Thompson's Construction to create an NFA. The resultant NFA can be used to directly test
// strings but the intended usage is to convert the NFA to a DFA and then minimize the DFA.
//
// [1] gives you some key constraints. NFAs derived form Thompson's construction have
// several specific properties that simplify an implementation. Each NFA has:
//
// 1. One start state.
// 2. One accepting state.
// 3. No transition, other than the initial transition, enters the start state.
// 4. No transition leaves the accepting state.
// 5. An epsilon-transition always connects two states that were, earlier in the process, the
//    start state and the accepting state.
// 6. Each state has at most two entering and two existing epsilon moves, OR at most
//    one entering and one exiting move on a symbol in the alphabet.
//
// References
//
// [1] Engineering a Compiler 2nd Edition section 2.4 (From Regular Expression to Scanner),
//     particularly pages 46-47.
class NFA {
  int _stateNumber = 0;
  NFAState _startState;
  NFAState _acceptingState;

  // fromRegularExpression uses Thompson's Construction to convert a RegularExpression tree
  // to a NFA. Again, reference is specifically [1] p46.
  NFA.fromRegularExpression(final RegularExpression root) {
    switch (root.kind) {
      case RegularExpressionKind.VALUE:
        var acceptingState = NFAState(_stateNumber++, [], true);
        var edge = NFAEdge(acceptingState, root.value);
        var startState = NFAState(_stateNumber++, [edge], false);
        _startState ??= startState;
        _acceptingState ??= acceptingState;
        break;
      case RegularExpressionKind.CLOSURE:
        throw UnsupportedError('not supported yet');
        break;
      case RegularExpressionKind.CONCATENATION:
        throw UnsupportedError('not supported yet');
        break;
      case RegularExpressionKind.ALTERNATION:
        throw UnsupportedError('not supported yet');
        break;
    }
  }

  // matches attempts to match all of an input string to the NFA.
  //
  // This is not meant to be used directly. Rather you should convert the NFA to a DFA then
  // minimize it, and only then attempt matches. However this does let us test the NFAs.
  //
  // See [1]. We are pursuing option 2, taking one choice per non-deterministic choice, and
  // waiting still we exhaust the input and land on an accepting state.
  //
  // TODO maybe matches() is an interface?
  // TODO this code is identical for DFAs, see how to refactor later.
  //
  // [1] EaC2E section 2.4.1 (Nondeterministic Finite Automata) page 44.
  bool matches(final String input) {
    // Without ignoring this error Dart cannot infer the type of items popped from the queue.
    // ignore: omit_local_variable_types
    final ListQueue<NFAConfiguration> configurations =
        ListQueue.from([NFAConfiguration(_startState, 0)]);

    final lastIndex = input.length;
    while (configurations.isNotEmpty) {
      var currentConfiguration = configurations.removeLast();
      final currentInputIndex = currentConfiguration.inputIndex;
      if (currentInputIndex == lastIndex) {
        if (currentConfiguration.currentState.isAccepting) {
          // We've exhausted the input and this configuration is in an accepting state, so this
          // configuration of the NFA matches.
          return true;
        }
        // We've exhausted the input and this configuration isn't in an accepting state, so this
        // configuration of the NFA did not match. That's fine, we just continue onto other
        // configurations.
        continue;
      }

      // We haven't exhausted the input. Let's make choices and push a configuration per choice.
      // Every NFA edge out of this state is a choice. DFAs only have one outbound edge, but for
      // NFAs we are forced to simulate the world per edge.
      for (var edge in currentConfiguration.currentState.outboundEdges) {
        // The edge's RegularExpressionValue contains the logic for determining whether this
        // is an epsilon value or a literal value. Epsilon edges always match and consume nothing,
        // value edges need to be checked and consume some non-zero characters. If the match size
        // is -1 no match and this edge isn't matching.
        final matchSize = edge.value.getMatchSize(input, currentInputIndex);
        if (matchSize != -1) {
          var newConfiguration =
              NFAConfiguration(edge.endState, currentConfiguration.inputIndex + matchSize);

          // We're doing a breadth-first search, so add to the front of the queue.
          configurations.addFirst(newConfiguration);
        }
      }
    }

    // NFA configurations are empty and we didn't match, so amongst all the non-deterministic
    // choices nothing matches.
    return false;
  }
}

class NFAConfiguration {
  final NFAState _currentState;
  final int _inputIndex;

  const NFAConfiguration(this._currentState, this._inputIndex);

  int get inputIndex => _inputIndex;

  NFAState get currentState => _currentState;
}

class NFAState {
  final int _identifier;
  final List<NFAEdge> _outboundEdges;
  final bool _isAccepting;

  const NFAState(this._identifier, this._outboundEdges, this._isAccepting);

  List<NFAEdge> get outboundEdges => _outboundEdges;

  int get identifier => _identifier;

  bool get isAccepting => _isAccepting;
}

class NFAEdge {
  final NFAState _endState;
  final RegularExpressionValue _value;

  const NFAEdge(this._endState, this._value);

  NFAEdge.epsilon(this._endState) : _value = RegularExpressionValue.epsilon();

  RegularExpressionValue get value => _value;

  NFAState get endState => _endState;
}
