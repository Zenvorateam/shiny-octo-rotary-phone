import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';

typedef J = Map<String, dynamic>;

dynamic clone(dynamic o) => jsonDecode(jsonEncode(o));

/// Same behaviour as the website's num(): empty string = 0, junk = fallback.
num numOf(dynamic v, [num d = 0]) {
  if (v == null) return d;
  if (v is num) return v.isFinite ? v : d;
  if (v is bool) return v ? 1 : 0;
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return 0;
    return num.tryParse(s) ?? d;
  }
  return d;
}

bool truthy(dynamic v) {
  if (v == null || v == false) return false;
  if (v is num) return v != 0;
  if (v is String) return v.isNotEmpty && v != '0';
  return true;
}

/// Read a value by a dotted path, e.g. products.0.name
dynamic gp(dynamic o, String path) {
  dynamic cur = o;
  for (final k in path.split('.')) {
    if (cur == null) return null;
    if (cur is List) {
      final i = int.tryParse(k);
      if (i == null || i < 0 || i >= cur.length) return null;
      cur = cur[i];
    } else if (cur is Map) {
      cur = cur[k];
    } else {
      return null;
    }
  }
  return cur;
}

/// Write a value by a dotted path (creates missing maps).
void sp(dynamic root, String path, dynamic v) {
  final ks = path.split('.');
  dynamic cur = root;
  for (var i = 0; i < ks.length - 1; i++) {
    final k = ks[i];
    dynamic nx;
    if (cur is List) {
      nx = cur[int.parse(k)];
    } else {
      nx = cur[k];
      if (nx == null) {
        nx = <String, dynamic>{};
        cur[k] = nx;
      }
    }
    cur = nx;
  }
  final last = ks.last;
  if (cur is List) {
    cur[int.parse(last)] = v;
  } else {
    cur[last] = v;
  }
}

/// Deep merge: values from d win, keys missing in d keep b. Arrays are replaced.
dynamic merge(dynamic b, dynamic d) {
  if (b is! Map) return clone(d == null ? b : d);
  final o = <String, dynamic>{};
  final Map dm = d is Map ? d : <String, dynamic>{};
  final keys = <String>{...b.keys.map((e) => '$e'), ...dm.keys.map((e) => '$e')};
  for (final k in keys) {
    final x = b[k];
    if (!dm.containsKey(k)) {
      o[k] = clone(x);
      continue;
    }
    final y = dm[k];
    if (x is Map && y is Map) {
      o[k] = merge(x, y);
    } else {
      o[k] = clone(y);
    }
  }
  return o;
}

// ───────── formatting ─────────
String _group(String s) {
  if (s.length <= 3) return s;
  final last = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last';
}

String inr(num n) {
  final neg = n < 0;
  final a = n.abs();
  final ip = a.floor().toString();
  var frac = '';
  if (a % 1 != 0) {
    var f = (a - a.floor()).toStringAsFixed(2).substring(1);
    f = f.replaceAll(RegExp(r'0+$'), '');
    if (f == '.') f = '';
    frac = f;
  }
  return '${neg ? '-' : ''}${_group(ip)}$frac';
}

String money(num n) => '₹${inr(n)}';

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String dShort(DateTime d) => '${_wd[d.weekday - 1]}, ${d.day} ${_mo[d.month - 1]}';
String dDay(DateTime d) => '${d.day} ${_mo[d.month - 1]}';
String dFull(DateTime d) => '${d.day} ${_mo[d.month - 1]} ${d.year}';
String tHm(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'pm' : 'am'}';
}

DateTime msDate(dynamic ms) => DateTime.fromMillisecondsSinceEpoch(numOf(ms).toInt());
int nowMs() => DateTime.now().millisecondsSinceEpoch;

// ───────── css colours and gradients ─────────
int _ch(num v) => v.round().clamp(0, 255).toInt();

Color? parseColor(String s0) {
  final s = s0.trim().toLowerCase();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) {
    var h = s.substring(1);
    if (h.length == 3 || h.length == 4) h = h.split('').map((c) => '$c$c').join();
    if (h.length == 6) {
      final v = int.tryParse(h, radix: 16);
      return v == null ? null : Color(0xFF000000 | v);
    }
    if (h.length == 8) {
      final v = int.tryParse(h, radix: 16);
      if (v == null) return null;
      final a = v & 0xFF;
      return Color((a << 24) | (v >> 8));
    }
    return null;
  }
  final m = RegExp(r'^rgba?\(([^)]*)\)$').firstMatch(s);
  if (m != null) {
    final p = m.group(1)!.split(RegExp(r'[,\s/]+')).where((e) => e.isNotEmpty).toList();
    if (p.length >= 3) {
      num c(String x) => x.endsWith('%') ? (num.tryParse(x.replaceAll('%', '')) ?? 0) * 2.55 : (num.tryParse(x) ?? 0);
      var a = 1.0;
      if (p.length > 3) {
        final t = p[3];
        a = t.endsWith('%') ? (double.tryParse(t.replaceAll('%', '')) ?? 100) / 100 : (double.tryParse(t) ?? 1);
      }
      return Color.fromARGB(_ch(a * 255), _ch(c(p[0])), _ch(c(p[1])), _ch(c(p[2])));
    }
    return null;
  }
  switch (s) {
    case 'white':
      return const Color(0xFFFFFFFF);
    case 'black':
      return const Color(0xFF000000);
    case 'transparent':
      return const Color(0x00000000);
  }
  return null;
}

List<String> _splitTop(String s) {
  final out = <String>[];
  var depth = 0;
  var b = StringBuffer();
  for (final ch in s.split('')) {
    if (ch == '(') depth++;
    if (ch == ')') depth--;
    if (ch == ',' && depth == 0) {
      out.add(b.toString().trim());
      b = StringBuffer();
    } else {
      b.write(ch);
    }
  }
  out.add(b.toString().trim());
  return out;
}

/// Turns a css value like "linear-gradient(135deg,#fff,#000 55%)", "var(--gd)" or "#fff" into a Flutter gradient.
LinearGradient? parseGradient(String css, Map<String, String> vars, [int depth = 0]) {
  final s = css.trim();
  if (depth > 4 || s.isEmpty) return null;
  final vm = RegExp(r'^var\(\s*(--[\w-]+)\s*(?:,[^)]*)?\)$').firstMatch(s);
  if (vm != null) {
    final v = vars[vm.group(1)!];
    return v == null ? null : parseGradient(v, vars, depth + 1);
  }
  final lm = RegExp(r'^(?:repeating-)?linear-gradient\((.*)\)$', dotAll: true).firstMatch(s);
  if (lm == null) {
    final c = parseColor(s);
    return c == null ? null : LinearGradient(colors: [c, c]);
  }
  final parts = _splitTop(lm.group(1)!);
  var angle = 180.0;
  var start = 0;
  final first = parts.first.toLowerCase();
  final am = RegExp(r'^(-?[\d.]+)deg$').firstMatch(first);
  if (am != null) {
    angle = double.tryParse(am.group(1)!) ?? 180;
    start = 1;
  } else if (first.startsWith('to ')) {
    start = 1;
    switch (first.substring(3).trim()) {
      case 'top':
        angle = 0;
        break;
      case 'right':
        angle = 90;
        break;
      case 'left':
        angle = 270;
        break;
      case 'bottom right':
        angle = 135;
        break;
      case 'bottom left':
        angle = 225;
        break;
      case 'top right':
        angle = 45;
        break;
      case 'top left':
        angle = 315;
        break;
      default:
        angle = 180;
    }
  }
  final colors = <Color>[];
  final pos = <double?>[];
  for (final p in parts.skip(start)) {
    final m = RegExp(r'^(.*?)(?:\s+(-?[\d.]+)%)?$').firstMatch(p);
    if (m == null) continue;
    final c = parseColor(m.group(1)!);
    if (c == null) continue;
    colors.add(c);
    final t = m.group(2);
    pos.add(t == null ? null : (double.tryParse(t) ?? 0) / 100);
  }
  final n = colors.length;
  if (n == 0) return null;
  if (n == 1) return LinearGradient(colors: [colors[0], colors[0]]);
  final st = List<double?>.from(pos);
  st[0] ??= 0.0;
  st[n - 1] ??= 1.0;
  var i = 0;
  while (i < n) {
    if (st[i] != null) {
      i++;
      continue;
    }
    var j = i;
    while (st[j] == null) {
      j++;
    }
    final a = st[i - 1]!;
    final b = st[j]!;
    for (var k = i; k < j; k++) {
      st[k] = a + (b - a) * (k - i + 1) / (j - i + 1);
    }
    i = j + 1;
  }
  final stops = <double>[];
  var prev = 0.0;
  for (final v in st) {
    final x = math.max(prev, v!.clamp(0.0, 1.0).toDouble());
    stops.add(x);
    prev = x;
  }
  final r = angle * math.pi / 180;
  var dx = math.sin(r);
  var dy = -math.cos(r);
  final mx = math.max(dx.abs(), dy.abs());
  if (mx > 0) {
    dx /= mx;
    dy /= mx;
  }
  return LinearGradient(colors: colors, stops: stops, begin: Alignment(-dx, -dy), end: Alignment(dx, dy));
}

/// Very small html helper: removes tags, keeps text. (<br> becomes a new line)
String stripHtml(String s) => s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n').replaceAll(RegExp(r'<[^>]*>'), '');
