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

/// Resolve o código da filial a partir do código da empresa.
int? resolverCodFilial(String? empresaCodigo) {
  if (empresaCodigo == null || empresaCodigo.isEmpty) {
    return 1;
  }
  final parsed = int.tryParse(empresaCodigo);
  return parsed ?? 1;
}
