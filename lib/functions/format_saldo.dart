import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '/core/app_functions.dart';
import '/core/lat_lng.dart';
import '/core/place.dart';
import '/core/uploaded_file.dart';
import '/backend/schema/structs/index.dart';

/// DSL custom function formatSaldo
String? formatSaldo(
  double? saldo,
  String? unidade,
) {
  return 'Saldo: ${saldo ?? 0.0} ${unidade ?? ""}';
}
