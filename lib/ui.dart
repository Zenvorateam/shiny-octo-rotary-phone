import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core.dart';
import 'services.dart';
import 'state.dart';

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

const dark15 = Color(0xFF15161A);
const gold1 = Color(0xFFF0D27A);
const goodGreen = Color(0xFF1E7A45);
const errRed = Color(0xFFB04030);

String tx(String s) => app.tx(s);

String nn(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();

void toast(String m) {
  final s = rootMessengerKey.currentState;
  if (s == null) return;
  s.hideCurrentSnackBar();
  s.showSnackBar(SnackBar(
    content: Text(m, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
    backgroundColor: dark15,
    behavior: SnackBarBehavior.floating,
    shape: const StadiumBorder(),
    margin: const EdgeInsets.fromLTRB(28, 0, 28, 90),
    duration: const Duration(milliseconds: 2200),
  ));
}

void closeAll(BuildContext c) => Navigator.of(c).popUntil((r) => r.isFirst);

Future<T?> go<T>(BuildContext c, Widget w) => Navigator.of(c).push<T>(MaterialPageRoute<T>(builder: (_) => w));

// ───────── text styles ─────────
TextStyle hs(double s, {FontWeight w = FontWeight.w800, Color? c, double? h}) {
  final fam = app.fontH.isEmpty ? 'Bricolage Grotesque' : app.fontH;
  try {
    return GoogleFonts.getFont(fam, fontSize: s, fontWeight: w, color: c ?? app.ink, height: h, letterSpacing: -0.02 * s);
  } catch (_) {
    return TextStyle(fontSize: s, fontWeight: w, color: c ?? app.ink, height: h, letterSpacing: -0.02 * s);
  }
}

TextStyle ts(double s, {FontWeight w = FontWeight.w400, Color? c, double? h, TextDecoration? d}) =>
    TextStyle(fontSize: s, fontWeight: w, color: c ?? app.ink, height: h, decoration: d);

// ───────── buttons / boxes ─────────
class Btn extends StatelessWidget {
  final String t;
  final VoidCallback? onTap;
  final String k; // dk, ol, gold, rd
  final bool full;
  final double h, fs;
  final bool raw; // do not run text replacement
  const Btn(this.t, this.onTap, {super.key, this.k = 'dk', this.full = false, this.h = 48, this.fs = 14, this.raw = false});

  @override
  Widget build(BuildContext c) {
    final dk = k == 'dk', gold = k == 'gold', rd = k == 'rd';
    final fg = dk ? Colors.white : (gold ? dark15 : (rd ? const Color(0xFFAA3333) : app.ink));
    final deco = BoxDecoration(
      gradient: dk ? app.gd : (gold ? app.gg : null),
      color: dk || gold ? null : Colors.white,
      borderRadius: BorderRadius.circular(99),
      border: dk || gold ? null : Border.all(color: rd ? const Color(0xFFECC7C7) : const Color(0xFFD4D7E4)),
      boxShadow: dk ? const [BoxShadow(color: Color(0x300B0C10), blurRadius: 20, offset: Offset(0, 8))] : null,
    );
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Ink(
            decoration: deco,
            child: Container(
              height: h,
              padding: EdgeInsets.symmetric(horizontal: h >= 44 ? 22 : 14),
              child: Row(
                mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Flexible(child: Text(raw ? t : tx(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: fs)))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoundBtn extends StatelessWidget {
  final String ch;
  final VoidCallback onTap;
  final double size;
  final bool dark;
  const RoundBtn(this.ch, this.onTap, {super.key, this.size = 40, this.dark = false});
  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dark ? const Color(0x26FFFFFF) : const Color(0xFFF1F2F4)),
          child: Text(ch, style: TextStyle(fontSize: 18, color: dark ? Colors.white : app.ink, fontWeight: FontWeight.w700)),
        ),
      );
}

class Blk extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Gradient? gradient;
  final Color? border;
  final EdgeInsets pad;
  final EdgeInsets margin;
  final double radius;
  const Blk({super.key, required this.child, this.color, this.gradient, this.border, this.pad = const EdgeInsets.all(15), this.margin = const EdgeInsets.symmetric(vertical: 6), this.radius = 20});
  @override
  Widget build(BuildContext c) => Container(
        width: double.infinity,
        margin: margin,
        padding: pad,
        decoration: BoxDecoration(color: gradient == null ? (color ?? Colors.white) : null, gradient: gradient, borderRadius: BorderRadius.circular(radius), border: Border.all(color: border ?? app.line)),
        child: child,
      );
}

class Pill extends StatelessWidget {
  final String t;
  final bool on;
  final VoidCallback? onTap;
  final bool raw;
  const Pill(this.t, {super.key, this.on = false, this.onTap, this.raw = false});
  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(gradient: on ? app.gd : null, color: on ? null : Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: on ? Colors.transparent : app.line)),
          child: Text(raw ? t : tx(t), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : app.ink)),
        ),
      );
}

/// Radio-like option row (.opt in the website)
class Opt extends StatelessWidget {
  final String title;
  final String? sub;
  final bool on;
  final VoidCallback onTap;
  final bool raw;
  const Opt({super.key, required this.title, this.sub, required this.on, required this.onTap, this.raw = false});
  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: on ? const Color(0xFFFBFBFC) : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? app.ink : app.line, width: on ? 1.5 : 1)),
          child: Row(children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? app.ink : const Color(0xFFB9BDC8), width: 2)),
              child: on ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: app.ink))) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(raw ? title : tx(title), style: ts(14, w: FontWeight.w700)),
                if (sub != null) Text(raw ? sub! : tx(sub!), style: ts(12, c: app.mut)),
              ]),
            ),
          ]),
        ),
      );
}

class SecHead extends StatelessWidget {
  final String title, sub;
  final Widget? trailing;
  const SecHead(this.title, this.sub, {super.key, this.trailing});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx(title), style: hs(20)), if (sub.isNotEmpty) Text(tx(sub), style: ts(12, c: app.mut))])),
          if (trailing != null) trailing!,
        ]),
      );
}

class BackLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const BackLink(this.label, this.onTap, {super.key});
  @override
  Widget build(BuildContext c) => Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('‹ ${tx(label)}', style: ts(14, w: FontWeight.w700))),
        ),
      );
}

/// Page used for both "panels" (title + close) and "pages" (back arrow).
class Screen extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget body;
  final Widget? footer;
  final List<Widget> actions;
  final bool panel, scroll;
  final EdgeInsets pad;
  final Color? bg;
  const Screen({super.key, required this.title, required this.body, this.sub, this.footer, this.actions = const [], this.panel = true, this.scroll = true, this.pad = const EdgeInsets.fromLTRB(16, 16, 16, 24), this.bg});

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: app,
        builder: (c, _) {
          final mq = MediaQuery.of(c);
          final top = mq.padding.top, bot = mq.padding.bottom;
          return Scaffold(
            backgroundColor: bg ?? app.paper,
            body: Column(children: [
              Container(
                padding: EdgeInsets.fromLTRB(16, top + 10, 12, 10),
                decoration: BoxDecoration(color: panel ? Colors.white : const Color(0xFFF3F4F8), border: Border(bottom: BorderSide(color: app.line))),
                child: Row(children: [
                  if (!panel) ...[RoundBtn('‹', () => Navigator.of(c).maybePop()), const SizedBox(width: 12)],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(tx(title), maxLines: 1, overflow: TextOverflow.ellipsis, style: hs(panel ? 20 : 19)),
                      if (sub != null) Text(tx(sub!), style: ts(12, c: app.mut)),
                    ]),
                  ),
                  ...actions,
                  if (panel) RoundBtn('✕', () => closeAll(c)),
                ]),
              ),
              Expanded(child: scroll ? SingleChildScrollView(padding: pad.copyWith(bottom: pad.bottom + (footer == null ? bot : 0)), child: body) : body),
              if (footer != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bot),
                  decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: app.line))),
                  child: footer,
                ),
            ]),
          );
        },
      );
}

class Footer2 extends StatelessWidget {
  final List<Widget> children;
  const Footer2(this.children, {super.key});
  @override
  Widget build(BuildContext c) => Row(children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 10), children[i]]]);
}

// ───────── images ─────────
final Map<String, MemoryImage> _memCache = {};

ImageProvider? _dataProvider(String url) {
  try {
    return _memCache.putIfAbsent(url, () => MemoryImage(base64Decode(url.substring(url.indexOf(',') + 1))));
  } catch (_) {
    return null;
  }
}

Widget pimg(String url, {BoxFit fit = BoxFit.cover, Alignment align = Alignment.center}) {
  Widget ph() => Container(decoration: BoxDecoration(gradient: app.gl), alignment: Alignment.center, child: const Icon(Icons.image_outlined, color: Color(0x33000000), size: 28));
  if (url.isEmpty) return ph();
  if (url.startsWith('data:')) {
    final p = _dataProvider(url);
    if (p == null) return ph();
    return Image(image: p, fit: fit, alignment: align, gaplessPlayback: true, errorBuilder: (_, __, ___) => ph());
  }
  return Image.network(
    url,
    fit: fit,
    alignment: align,
    errorBuilder: (_, __, ___) => ph(),
    loadingBuilder: (c, child, prog) => prog == null ? child : ph(),
  );
}

Widget avatar(J? u, {double size = 34, bool pr = false, bool gold = false, bool onDark = false}) {
  final name = '${u?['n'] ?? '?'}';
  final letter = name.isEmpty ? '?' : name[0].toUpperCase();
  final photo = '${u?['photo'] ?? ''}';
  Widget inner;
  if (photo.isNotEmpty) {
    inner = pimg(photo);
  } else {
    inner = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(gradient: gold ? null : (onDark ? app.gg : app.gd), color: gold ? dark15 : null),
      child: Text(letter, style: hs(size * 0.45, c: gold ? gold1 : (onDark ? dark15 : Colors.white))),
    );
  }
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, border: pr ? Border.all(color: const Color(0xFFE0B95F), width: 2) : null),
    child: ClipOval(child: SizedBox(width: size, height: size, child: inner)),
  );
}

// ───────── mini html ─────────
String _entities(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

List<InlineSpan> inlineSpans(String html, TextStyle base, {bool hideBold = false}) {
  final out = <InlineSpan>[];
  final re = RegExp(r'<(/?)(b|strong|i|em|u|br)\b[^>]*>', caseSensitive: false);
  var bold = 0, ital = 0, pos = 0;
  void add(String t) {
    final clean = _entities(t.replaceAll(RegExp(r'<[^>]*>'), ''));
    if (clean.isEmpty) return;
    if (hideBold && bold > 0) return;
    out.add(TextSpan(text: clean, style: base.copyWith(fontWeight: bold > 0 ? FontWeight.w800 : null, fontStyle: ital > 0 ? FontStyle.italic : null)));
  }

  for (final m in re.allMatches(html)) {
    add(html.substring(pos, m.start));
    pos = m.end;
    final close = m.group(1) == '/';
    final tag = m.group(2)!.toLowerCase();
    if (tag == 'br') {
      out.add(TextSpan(text: '\n', style: base));
    } else if (tag == 'b' || tag == 'strong') {
      bold += close ? -1 : 1;
      if (bold < 0) bold = 0;
    } else if (tag == 'i' || tag == 'em') {
      ital += close ? -1 : 1;
      if (ital < 0) ital = 0;
    }
  }
  add(html.substring(pos));
  return out;
}

List<Widget> htmlBlocks(String html, {Color? color}) {
  final col = color ?? app.ink;
  final blocks = <Widget>[];
  final re = RegExp(r'<(/?)(h[1-6]|p|ul|ol|li|div|br|hr)\b[^>]*>', caseSensitive: false);
  var pos = 0, mode = 'p', buf = StringBuffer(), n = 0;
  var ordered = false;
  void flush() {
    final t = buf.toString().trim();
    buf = StringBuffer();
    if (t.isEmpty) return;
    if (mode.startsWith('h')) {
      blocks.add(Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text.rich(TextSpan(children: inlineSpans(t, hs(18, c: col))))));
    } else if (mode == 'li') {
      n++;
      blocks.add(Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 22, child: Text(ordered ? '$n.' : '•', style: ts(14, c: col))),
          Expanded(child: Text.rich(TextSpan(children: inlineSpans(t, ts(14, c: col, h: 1.5))))),
        ]),
      ));
    } else {
      blocks.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: Text.rich(TextSpan(children: inlineSpans(t, ts(14, c: col, h: 1.55))))));
    }
  }

  for (final m in re.allMatches(html)) {
    buf.write(html.substring(pos, m.start));
    pos = m.end;
    final close = m.group(1) == '/';
    final tag = m.group(2)!.toLowerCase();
    if (tag == 'br') {
      buf.write('\n');
      continue;
    }
    flush();
    if (tag == 'hr') {
      blocks.add(Divider(color: app.line));
      continue;
    }
    if (close) {
      mode = 'p';
    } else if (tag.startsWith('h')) {
      mode = tag;
    } else if (tag == 'li') {
      mode = 'li';
    } else if (tag == 'ul' || tag == 'ol') {
      ordered = tag == 'ol';
      n = 0;
      mode = 'p';
    } else {
      mode = 'p';
    }
  }
  buf.write(html.substring(pos));
  flush();
  return blocks;
}

// ───────── stars ─────────
String stars(num n) {
  final r = n.round().clamp(0, 5).toInt();
  return '★' * r + '☆' * (5 - r);
}

// ───────── price details (bill) ─────────
class BillBox extends StatelessWidget {
  final Totals t;
  const BillBox(this.t, {super.key});

  Widget row(String a, String b, {String k = ''}) {
    Color vc = app.ink;
    var vs = 13.0;
    var vw = FontWeight.w400;
    if (k == 'g') {
      vc = goodGreen;
      vw = FontWeight.w700;
    }
    if (k == 'm') {
      vc = app.mut;
      vs = 12;
    }
    if (k == 's') vw = FontWeight.w700;
    if (k == 't') {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: app.ink, width: 1.5))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(tx(a), style: hs(18)), Text(b, style: hs(18))]),
      );
    }
    return Container(
      margin: EdgeInsets.only(top: k == 's' ? 4 : 0),
      padding: EdgeInsets.only(top: k == 's' ? 9 : 5, bottom: 5),
      decoration: k == 's' ? BoxDecoration(border: Border(top: BorderSide(color: app.line))) : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(tx(a), style: ts(13, w: k == 's' ? FontWeight.w700 : FontWeight.w400))),
        const SizedBox(width: 12),
        Flexible(child: Text(b, textAlign: TextAlign.right, style: ts(vs, c: vc, w: vw))),
      ]),
    );
  }

  @override
  Widget build(BuildContext c) {
    final pr = t.pr;
    final mn = pr ? 'Prime' : 'Member';
    final th = pr ? app.ru.p : app.ru.n;
    final pct = t.sub > th[1] ? app.ru.pct[1] : (t.sub > th[0] ? app.ru.pct[0] : 0);
    final mv = t.kind == 'member' ? '−${money(t.disc)}' : (t.auto > 0 ? 'Not applied · coupon is better' : 'Unlocks above ${money(th[0])}');
    final cv = t.kind == 'coupon' ? '−${money(t.disc)}' : (t.couponDisc > 0 ? 'Not applied · membership is better' : 'Not applicable yet');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      row('Price (${t.n} item${t.n > 1 ? 's' : ''}, MRP)', money(t.mrp)),
      row('Store discount', '−${money(t.pd)}', k: 'g'),
      row('Subtotal', money(t.sub), k: 's'),
      if (t.cc.isNotEmpty) row('Coupon · ${t.cc}', cv, k: t.kind == 'coupon' ? 'g' : 'm'),
      row('$mn discount${pct > 0 ? ' (${nn(pct)}%)' : ''}', mv, k: t.kind == 'member' ? 'g' : 'm'),
      row('Delivery${pr ? ' · Prime' : ''}', t.ship > 0 ? money(t.ship) : 'Free', k: t.ship > 0 ? '' : 'g'),
      row('Total payable', money(t.total), k: 't'),
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 2),
        child: Text.rich(TextSpan(children: [TextSpan(text: tx('Tax breakup '), style: ts(13, w: FontWeight.w700)), TextSpan(text: tx('(included in total)'), style: ts(13, c: app.mut))])),
      ),
      row('Taxable value', money(t.tax)),
      row('CGST', money(t.cgst)),
      row('SGST', money(t.sgst)),
      row('Total GST', money(t.gst), k: 's'),
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFE3F3E8), borderRadius: BorderRadius.circular(14)),
        child: Text(tx('You saved ${money(t.pd + t.disc)} on this order'), textAlign: TextAlign.center, style: ts(13, w: FontWeight.w700, c: const Color(0xFF1E6B3F))),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(tx('GST shown at demo rates (apparel & footwear 5%, other items 18%), included in prices. Only the better of coupon or membership offer applies.'), style: ts(11, c: app.mut, h: 1.4)),
      ),
    ]);
  }
}

// ───────── delivery checker ─────────
class DeliveryChecker extends StatefulWidget {
  final bool embedded; // no card around it
  const DeliveryChecker({super.key, this.embedded = false});
  @override
  State<DeliveryChecker> createState() => _DeliveryCheckerState();
}

class _DeliveryCheckerState extends State<DeliveryChecker> {
  late final TextEditingController ctrl = TextEditingController(text: app.pin);
  String shown = app.pin, msg = '', mapUrl = '';

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> check() async {
    final pin = ctrl.text.trim();
    if (!okPin(pin)) {
      setState(() {
        msg = 'Enter a valid 6-digit PIN code.';
        shown = '';
      });
      return;
    }
    app.pin = pin;
    app.lsSet('pin', pin);
    setState(() {
      msg = 'Checking PIN $pin…';
      mapUrl = '';
    });
    await lookupPin(pin);
    if (!mounted) return;
    setState(() {
      msg = '';
      shown = pin;
    });
  }

  Future<void> locate() async {
    setState(() => msg = 'Getting your location…');
    final r = await locateMe();
    if (!mounted) return;
    if (r.error != null) {
      setState(() => msg = r.error!);
      return;
    }
    if (okPin(r.pin)) {
      ctrl.text = r.pin;
      app.pin = r.pin;
      app.lsSet('pin', r.pin);
      await lookupPin(r.pin);
      if (!mounted) return;
      setState(() {
        msg = '';
        shown = r.pin;
        mapUrl = r.mapUrl;
      });
    } else {
      setState(() {
        msg = 'Location found but the PIN couldn’t be read. Enter it manually.';
        mapUrl = r.mapUrl;
      });
    }
  }

  @override
  Widget build(BuildContext c) {
    final inner = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tx('Check delivery'), style: hs(16)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            onSubmitted: (_) => check(),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Enter PIN code',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide(color: app.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide(color: app.line)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Btn('Check', check, h: 46),
      ]),
      const SizedBox(height: 8),
      Btn('📍 Use location', locate, k: 'ol', full: true, h: 44),
      const SizedBox(height: 10),
      if (msg.isNotEmpty) Text(msg, style: ts(12, c: msg.startsWith('Enter a valid') || msg.startsWith('Location') ? errRed : app.mut)) else ResultBox(shown),
      if (mapUrl.isNotEmpty) GestureDetector(onTap: () => openUrl(mapUrl), child: Padding(padding: const EdgeInsets.only(top: 6), child: Text('View on Google Maps', style: ts(12, w: FontWeight.w700, d: TextDecoration.underline)))),
    ]);
    if (widget.embedded) return inner;
    return Blk(child: inner);
  }
}

class ResultBox extends StatelessWidget {
  final String pin;
  const ResultBox(this.pin, {super.key});

  Widget box(String a, String b, {bool gold = false, Widget? extra}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(gradient: gold ? app.gyl : app.gwg, border: Border.all(color: gold ? const Color(0xFFECD58A) : const Color(0xFFE3E5EA)), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx(a), style: ts(13, w: FontWeight.w800)),
          if (b.isNotEmpty) Text(tx(b), style: ts(12, c: app.mut, h: 1.4)),
          if (extra != null) extra,
        ]),
      );

  @override
  Widget build(BuildContext c) {
    if (!okPin(pin)) return Text(tx('Enter a 6-digit PIN to see your delivery date.'), style: ts(12, c: app.mut));
    final i = app.pinc[pin];
    if (i != null && i['ok'] == 0) return Text('We couldn’t find PIN $pin. Please check and try again.', style: ts(12, c: errRed));
    final verified = i != null && i['ok'] == 1;
    final more = verified && i['more'] is List && (i['more'] as List).isNotEmpty ? '\nAlso covers: ${(i['more'] as List).join(', ')}' : '';
    final adr = verified
        ? box('📍 ${i['area']}, ${i['dist']}', '${i['state']} – $pin · verified with India Post$more')
        : box('📍 ${stateOf(pin)} – $pin', 'Exact area couldn’t be verified (offline). Date is an estimate for this region.');
    final n = etaRange(pin, false), p = etaRange(pin, true);
    final days = nn(app.ru.pf);
    if (app.isPrime) {
      return Column(children: [adr, box('Prime: by $p', 'Free delivery · normal delivery would be $n', gold: true)]);
    }
    return Column(children: [
      adr,
      box('Delivery by $n', 'Free above ${money(app.ru.free)}, otherwise ${money(app.ru.fee)} · Pay online or COD'),
      box('With Prime: by $p', 'Free delivery, $days days earlier', gold: true,
          extra: GestureDetector(
              onTap: () => app.goPrimeCb?.call(c),
              child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(tx('Get Prime from ₹29'), style: ts(12, w: FontWeight.w800, d: TextDecoration.underline))))),
    ]);
  }
}

extension AppNav on AppState {
  static void Function(BuildContext)? _prime;
  void Function(BuildContext)? get goPrimeCb => _prime;
  set goPrimeCb(void Function(BuildContext)? f) => _prime = f;
}

// ───────── lightbox ─────────
Future<void> openLightbox(BuildContext c, List<String> imgs, int start) {
  return showDialog(
    context: c,
    barrierColor: const Color(0xEE0B0C10),
    builder: (_) => _Lightbox(imgs, start),
  );
}

class _Lightbox extends StatefulWidget {
  final List<String> imgs;
  final int start;
  const _Lightbox(this.imgs, this.start);
  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late int i = widget.start;
  late final PageController pc = PageController(initialPage: widget.start);
  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(children: [
          PageView(controller: pc, onPageChanged: (v) => setState(() => i = v), children: [for (final u in widget.imgs) InteractiveViewer(child: Center(child: pimg(u, fit: BoxFit.contain)))]),
          Positioned(right: 16, top: MediaQuery.of(c).padding.top + 12, child: RoundBtn('✕', () => Navigator.of(c).pop(), dark: true)),
          Positioned(left: 0, right: 0, bottom: 24, child: Text('${i + 1} / ${widget.imgs.length}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))),
        ]),
      );
}
