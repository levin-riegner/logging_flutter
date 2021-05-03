/// Flutter extension for logger
library logging_flutter;

import 'dart:collection';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'src/ansi_parser.dart';
import 'src/shake_detector.dart';

import 'flogger.dart';

part 'src/log_console_on_shake.dart';
part 'src/log_console.dart';
