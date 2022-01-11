// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:process/process.dart';
import 'package:test/test.dart';

void defaultStdResults(String s) {}

/// A mock that can be used to fake a process manager that runs commands
/// and returns results.
///
/// Call [setResults] to provide a list of results that will return from
/// each command line (with arguments).
///
/// Call [verifyCalls] to verify that each desired call occurred.
class FakeProcessManager implements ProcessManager {
  FakeProcessManager({this.stdinResults = defaultStdResults, this.isPeriodic = false});

  final bool isPeriodic;

  /// The callback that will be called each time stdin input is supplied to
  /// a call.
  final StringReceivedCallback stdinResults;

  /// The list of calls in sequence and results that will be sent back.
  /// Each command line has a stdout output that will be returned.
  List<Call> _calls = <Call>[];
  List<Call> get calls => _calls;
  set calls(List<Call> calls) {
    _calls = List<Call>.from(calls);
    _origCalls = calls;
  }

  /// Use for later verification.
  List<Call> _origCalls = [];

  String _getCommand(List<String> params) => params.join(' ');

  /// The list of invocations that occurred, in the order they occurred.
  List<Invocation> invocations = <Invocation>[];

  /// Verify that the given command lines were called, in the given order, and that the
  /// parameters were in the same order.
  void verifyCalls() {
    // unused calls
    expect(calls, isEmpty, reason: 'Remove calls from end of call list.');
    expect(invocations.length, equals(_origCalls.length));

    // replay invocations and compare to orig
    for (var i = 0; i < invocations.length; i++) {
      final command = _getCommand(invocations[i].positionalArguments[0]);
      expect(command, equals(_origCalls[i].command));
      // check parameter positions
//      expect(_origCalls[i].command.split(' '),
//          orderedEquals(invocations[i].positionalArguments[0]));
    }
  }

  ProcessResult _popResult(List<String> command) {
    // 1. Pop off call list
    // 2. Confirm correct command
    // 3. Run side effects
    // 4. Return process result
    final key = command.join(' ');
    expect(calls, isNotEmpty,
        reason: 'All calls have been executed. Add call for command \'$key\'');
    final call = calls.removeAt(0);
    expect(call.command, equals(key),
        reason:
            'Incorrect call in sequence. Add \'$key\' to calls before \'${call.command}\' at position ${_origCalls.length - calls.length}');
    if (call.sideEffects != null) call.sideEffects!();
    return call.result;
  }

  FakeProcess _popProcess(List<String> command) =>
      FakeProcess(_popResult(command),
          stdinResults: stdinResults, isPeriodic: isPeriodic);

  Future<Process> _nextProcess(Invocation invocation) async {
    invocations.add(invocation);
    return Future<Process>.value(
        _popProcess(invocation.positionalArguments[0]));
  }

  ProcessResult _nextResultSync(Invocation invocation) {
    invocations.add(invocation);
    return _popResult(invocation.positionalArguments[0]);
  }

  Future<ProcessResult> _nextResult(Invocation invocation) async {
    invocations.add(invocation);
    return Future<ProcessResult>.value(
        _popResult(invocation.positionalArguments[0]));
  }

  @override
  Future<Process> start(List<Object>? command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool? includeParentEnvironment,
    bool? runInShell,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) =>
      _nextProcess(Invocation.method(#start, [
        command
      ], {
        #workingDirectory: workingDirectory,
        #environment: environment,
        #includeParentEnvironment: includeParentEnvironment,
        #runInShell: runInShell,
        #mode: mode,
      }));

  @override
  Future<ProcessResult> run(
    List<Object>? command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool? includeParentEnvironment,
    bool? runInShell,
    covariant Encoding? stdoutEncoding = systemEncoding,
    covariant Encoding? stderrEncoding = systemEncoding,
  }) =>
      _nextResult(Invocation.method(#run, [
        command
      ], {
        #workingDirectory: workingDirectory,
        #environment: environment,
        #includeParentEnvironment: includeParentEnvironment,
        #runInShell: runInShell,
        #stdoutEncoding: stdoutEncoding,
        #stderrEncoding: stderrEncoding,
      }));

  @override
  ProcessResult runSync(List<Object>? command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool? includeParentEnvironment,
    bool? runInShell,
    covariant Encoding? stdoutEncoding = systemEncoding,
    covariant Encoding? stderrEncoding = systemEncoding,
  }) =>
      _nextResultSync(Invocation.method(#runSync, [
        command
      ], {
        #workingDirectory: workingDirectory,
        #environment: environment,
        #includeParentEnvironment: includeParentEnvironment,
        #runInShell: runInShell,
        #stdoutEncoding: stdoutEncoding,
        #stderrEncoding: stderrEncoding,
      }));

  @override
  bool killPid(int? pid, [ProcessSignal? signal]) => true;

  @override
  bool canRun(dynamic executable, {String? workingDirectory}) => true;
}

/// A fake process that can be used to interact with a process "started" by the FakeProcessManager.
class FakeProcess implements Process {
  FakeProcess(ProcessResult result,
      {required void Function(String input) stdinResults, bool isPeriodic = false})
      : stderrStream = Stream<List<int>>.fromIterable(
            <List<int>>[result.stderr.codeUnits]),
        desiredExitCode = result.exitCode,
        stdinSink = IOSink(StringStreamConsumer(stdinResults)),
        stdoutStream = isPeriodic
            ? result.stdout
            : Stream<List<int>>.fromIterable(
                <List<int>>[result.stdout.codeUnits]);

  final IOSink stdinSink;
  Stream<List<int>> stdoutStream;
  final Stream<List<int>> stderrStream;
  final int desiredExitCode;

  @override
  bool kill([ProcessSignal? signal = ProcessSignal.sigterm]) => true;

  @override
  Future<int> get exitCode => Future<int>.value(desiredExitCode);

  @override
  int get pid => 0;

  @override
  IOSink get stdin => stdinSink;

  @override
  Stream<List<int>> get stderr => stderrStream;

  @override
  Stream<List<int>> get stdout => stdoutStream;
}

/// Callback used to receive stdin input when it occurs.
typedef StringReceivedCallback = void Function(String received);

/// A stream consumer class that consumes UTF8 strings as lists of ints.
class StringStreamConsumer implements StreamConsumer<List<int>> {
  StringStreamConsumer(this.sendString);

  List<Stream<List<int>>> streams = <Stream<List<int>>>[];
  List<StreamSubscription<List<int>>> subscriptions =
      <StreamSubscription<List<int>>>[];
  List<Completer<dynamic>> completers = <Completer<dynamic>>[];

  /// The callback called when this consumer receives input.
  StringReceivedCallback sendString;

  @override
  Future<dynamic> addStream(Stream<List<int>> value) {
    streams.add(value);
    completers.add(Completer<dynamic>());
    subscriptions.add(
      value.listen((List<int> data) {
        sendString(utf8.decode(data));
      }),
    );
    subscriptions.last.onDone(() => completers.last.complete(null));
    return Future<dynamic>.value(null);
  }

  @override
  Future<dynamic> close() async {
    for (var completer in completers) {
      await completer.future;
    }
    completers.clear();
    streams.clear();
    subscriptions.clear();
    return Future<dynamic>.value(null);
  }
}

class Call {
  final String command;
  final ProcessResult result;
  final Function? sideEffects;

  Call(this.command, ProcessResult? result, {this.sideEffects})
      : result = result ?? ProcessResult(0, 0, '', '');

  @override
  String toString() {
    return 'call: command: $command, sideEffects: $sideEffects';
  }
}
