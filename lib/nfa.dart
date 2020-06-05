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
  final NFAState _startState;
  final NFAState _endState;

  NFA(this._startState, this._endState);

  // fromRegularExpression uses Thompson's Construction to convert a RegularExpression tree
  // to a NFA. Again, reference is specifically [1] p46.
  factory NFA.fromRegularExpression(final RegularExpression root) {
    var stateNumber = 0;
    final Queue<NFA> nfaStack = ListQueue<NFA>();
    final regexIterator = RegularExpressionPostOrderIterator(root);
    while (regexIterator.moveNext()) {
      final currentRegex = regexIterator.current;
      switch (currentRegex.kind) {
        case RegularExpressionKind.VALUE:
          final endState = NFAState(stateNumber++, [], false);
          final edge = NFAEdge(endState, currentRegex.value);
          final startState = NFAState(stateNumber++, [edge], false);
          final currentNFA = NFA(startState, endState);
          nfaStack.addLast(currentNFA);
          break;
        case RegularExpressionKind.CLOSURE:
          // Closure can:
          // 1) skip the NFA with an epsilon edge, OR
          // 2) go back from the end state to the start state with an epsilon edge.

          // this is 1), we just skip the existing NFA entirely with an epsilon edge
          final endState = NFAState(stateNumber++, [], false);
          final edgeSkip = NFAEdge.epsilon(endState);
          final startState = NFAState(stateNumber++, [edgeSkip], false);

          // this is 2)
          final nfa = nfaStack.removeLast();
          startState.addOutputEdge(NFAEdge.epsilon(nfa._startState));
          nfa._endState.addOutputEdge(NFAEdge.epsilon(nfa._startState));
          nfa._endState.addOutputEdge(NFAEdge.epsilon(endState));

          final newNfa = NFA(startState, endState);
          nfaStack.addLast(newNfa);
          break;

        case RegularExpressionKind.CONCATENATION:
          // NFA a is (s_1) -> a -> ((s_2))
          // NFA b is (s_3) -> b -> ((s_4))
          //
          // Thompson's construction concatenates them with an epsilon edge
          //
          // (s_1) -> a -> (s_2) -> epsilon -> (s_3) -> ((s_4))
          final nfaSecond = nfaStack.removeLast();
          final nfaFirst = nfaStack.removeLast();
          final epsilonEdge = NFAEdge.epsilon(nfaSecond._startState);
          nfaFirst._endState.outboundEdges = [epsilonEdge];
          final endState = nfaSecond._endState;
          final startState = nfaFirst._startState;
          final newNfa = NFA(startState, endState);
          nfaStack.addLast(newNfa);
          break;

        case RegularExpressionKind.ALTERNATION:
          // Join two NFAs with
          // 1) a single state and 2 epsilon edges to both starts, and
          // 2) a single state and 2 epsilon edges as new end from two ends
          final nfaSecond = nfaStack.removeLast();
          final nfaFirst = nfaStack.removeLast();
          final epsilonEdgeToFirst = NFAEdge.epsilon(nfaFirst._startState);
          final epsilonEdgeToSecond = NFAEdge.epsilon(nfaSecond._startState);
          final newStartState =
              NFAState(stateNumber++, [epsilonEdgeToFirst, epsilonEdgeToSecond], false);

          final newEndState = NFAState(stateNumber++, [], true);
          final epsilonEdgeFromFirst = NFAEdge.epsilon(newEndState);
          final epsilonEdgeFromSecond = NFAEdge.epsilon(newEndState);
          nfaFirst._endState.outboundEdges = [epsilonEdgeFromFirst];
          nfaFirst._endState.isAccepting = false;
          nfaSecond._endState.outboundEdges = [epsilonEdgeFromSecond];
          nfaSecond._endState.isAccepting = false;

          final newNfa = NFA(newStartState, newEndState);
          nfaStack.addLast(newNfa);
          break;
      }
    }

    if (nfaStack.length != 1) {
      throw StateError('NFA stack should only have one NFA left');
    }
    final nfa = nfaStack.removeLast();
    nfa._endState.isAccepting = true;
    return nfa;
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
    final Queue<NFAConfiguration> configurations = ListQueue();
    configurations.addFirst(NFAConfiguration(_startState, 0));

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
        // We've exhausted the input and this configuration isn't in an accepting state. However
        // there may still be epsilon edges going out of this state. There's no harm in
        // letting this play out.
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
          var newConfiguration = NFAConfiguration(edge.endState, currentInputIndex + matchSize);

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
  List<NFAEdge> _outboundEdges;
  bool _isAccepting;

  NFAState(this._identifier, this._outboundEdges, this._isAccepting);

  List<NFAEdge> get outboundEdges => _outboundEdges;

  int get identifier => _identifier;

  bool get isAccepting => _isAccepting;

  set isAccepting(bool value) {
    _isAccepting = value;
  }

  set outboundEdges(List<NFAEdge> value) {
    _outboundEdges = value;
  }

  void addOutputEdge(final NFAEdge edge) {
    _outboundEdges.add(edge);
  }
}

class NFAEdge {
  final NFAState _endState;
  final RegularExpressionValue _value;

  const NFAEdge(this._endState, this._value);

  NFAEdge.epsilon(this._endState) : _value = RegularExpressionValue.epsilon();

  RegularExpressionValue get value => _value;

  NFAState get endState => _endState;
}
