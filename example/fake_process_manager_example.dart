//import 'dart:io';

import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:process/process.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

import 'call_process.dart';

main() {
  FakeProcessManager fakeProcessManager;

  setUp(() async {
    fakeProcessManager = FakeProcessManager();
  });

  testUsingContext('test', () {
    final cmd = 'date';
    final cmdResult = 'todays date';
    fakeProcessManager.calls = [Call(cmd, ProcessResult(0, 0, cmdResult, ''))];
    final result = runCmd(<String>[cmd]);
    expect(result, equals(cmdResult));
    fakeProcessManager.verifyCalls();
  }, overrides: <Type, Generator>{
    ProcessManager: () => fakeProcessManager,
    Logger: () => VerboseLogger(StdoutLogger()),
  });
}
