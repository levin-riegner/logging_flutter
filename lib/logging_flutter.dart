/// Flutter extension for logger
library logging_flutter;

import 'dart:collection';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'src/ansi_parser.dart';
import 'src/shake_detector.dart';

export 'src/shake_detector.dart';

part 'src/log_console_on_shake.dart';
part 'src/log_console.dart';
