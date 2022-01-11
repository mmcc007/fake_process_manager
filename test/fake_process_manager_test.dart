// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:fake_process_manager/src/fake_process_manager.dart';
import 'package:test/test.dart';

void main() {
  group('fake process manager', () {
    var processManager = FakeProcessManager();
    final stdinCaptured = <String>[];

    void _captureStdin(String item) {
      stdinCaptured.add(item);
    }

    setUp(() async {
      processManager = FakeProcessManager(stdinResults: _captureStdin);
    });

    tearDown(() async {});

    test('start works', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil cat gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;
      for (var call in calls) {
        final key = call.command;
        final process = await processManager.start(key.split(' '));
        var output = '';
        process.stdout.listen((List<int> item) {
          output += utf8.decode(item);
        });
        await process.exitCode;
        expect(output, equals(call.result.stdout));
      }
      processManager.verifyCalls();
    });

    test('run works', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil cat gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;
      for (var call in calls) {
        final key = call.command;
        final result = await processManager.run(key.split(' '));
        expect(result.stdout, equals(call.result.stdout));
      }
      processManager.verifyCalls();
    });

    test('runSync works', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil cat gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;
      for (var call in calls) {
        final key = call.command;
        final result = processManager.runSync(key.split(' '));
        expect(result.stdout, equals(call.result.stdout));
      }
      processManager.verifyCalls();
    });

    test('captures stdin', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil cat gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;
      for (var call in calls) {
        final key = call.command;
        final process = await processManager.start(key.split(' '));
        var output = '';
        process.stdout.listen((List<int> item) {
          output += utf8.decode(item);
        });
        final testInput = '${call.result.stdout} input';
        process.stdin.add(testInput.codeUnits);
        await process.exitCode;
        expect(output, equals(call.result.stdout));
        expect(stdinCaptured.last, equals(testInput));
      }
      processManager.verifyCalls();
    });
  });

  group('additional fake process manager tests', () {
    var processManager = FakeProcessManager();

    setUp(() async {
      processManager = FakeProcessManager();
    });

    test('repeated calls', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;
      for (var call in calls) {
        final key = call.command;
        final result = processManager.runSync(key.split(' '));
        expect(result.stdout, equals(call.result.stdout));
      }
      processManager.verifyCalls();
    });

    test('unused calls', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil cat gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;
      final key = calls[0].command;
      processManager.runSync(key.split(' '));
//      expect(() => processManager.verifyCalls(), throwsA(TestFailure));
    });

    test('out of sequence calls', () async {
      final calls = [
        Call('gsutil acl get gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output1', '')),
        Call('gsutil cat gs://flutter_infra/releases/releases.json',
            ProcessResult(0, 0, 'output2', '')),
      ];
      processManager.calls = calls;

//      final key = calls[1].command;
//      processManager.runSync(key.split(' '));
    });

    test('side effects', () {
      final testDir = '/tmp/test_fakeProcessManager';
      final newFile = '$testDir/newFile.txt';
      if (Directory(testDir).existsSync()) {
        Directory(testDir).deleteSync(recursive: true);
      }
      Directory(testDir).createSync(recursive: true);
      final calls = [
        Call('my command', null, sideEffects: () => File(newFile).createSync())
      ];
      processManager.calls = calls;
      final key = calls[0].command;
      processManager.runSync(key.split(' '));
      expect(File(newFile).existsSync(), isTrue);
      processManager.verifyCalls();
    });
  });
}
