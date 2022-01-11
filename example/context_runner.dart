// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:process/process.dart';
import 'package:tool_base/tool_base.dart';

Future<T> runInContext<T>(
  FutureOr<T> Function() runner, {
  Map<Type, Generator>? overrides,
}) async {
  return await context.run<T>(
    name: 'global fallbacks',
    body: runner,
    overrides: overrides,
    fallbacks: <Type, Generator>{
      BotDetector: () => const BotDetector(),
      Config: () => Config(),
      Logger: () => platform.isWindows ? WindowsStdoutLogger() : StdoutLogger(),
      OperatingSystemUtils: () => OperatingSystemUtils(),
      ProcessManager: () => LocalProcessManager(),
      Stdio: () => const Stdio(),
      TimeoutConfiguration: () => const TimeoutConfiguration(),
    },
  );
}
