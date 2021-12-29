import 'dart:isolate';
import 'package:airhost_lint_plugin/starter.dart';

void main(List<String> args, SendPort sendPort) {
  start(args, sendPort);
}