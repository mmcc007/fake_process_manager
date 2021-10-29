import 'package:tool_base/tool_base.dart';

import 'context_runner.dart';

void main() {
  runInContext<void>(() async {
    print(runCmd(['ls', '-la']));
  });
}

String runCmd(List<Object> cmd) {
  printTrace('executing: ${cmd.join(' ')}');
  final process = processManager.runSync(cmd);
  printTrace('executed: ${cmd.join(' ')} ==> ${process.stdout}');
  return process.stdout;
}
