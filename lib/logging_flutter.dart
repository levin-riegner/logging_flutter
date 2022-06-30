/// Flutter extension for logger
library logging_flutter;

import 'dart:collection';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'src/ansi_parser.dart';

export 'package:logging/src/level.dart';
export 'flogger.dart';

part 'src/log_console.dart';
