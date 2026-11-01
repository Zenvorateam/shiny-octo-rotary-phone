import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'core.dart';
import 'data.dart';

final app = AppState();

const gstRates = {'Fashion': 5, 'Accessories': 18, 'Home': 18, 'Essentials': 18};
const catIcons = ['♧', '⌂', '◇', '✳', '◈', '❖'];
const stageLabels = ['Order placed', 'Packed', 'Out for delivery', 'Delivered'];
const stageShort = ['Placed', 'Packed', 'On the way', 'Delivered'];
const stageSub = ['We received your order', 'Items packed at our warehouse', 'Your order is out for delivery', 'Cash collected. Enjoy!'];
const demoReviews = [
  ['Aditi', 'Great quality, fits exactly as shown.', 5],
  ['Rahul', 'Value for money. Delivery was quick.', 4],
];

// ───────── models ─────────
class Product {
  final int id;
  final String name, brand, category, stock, image, description;
  final num price, mrp, rating;
  final int views;
  final List<J> colors;
  final List<List<String>> spec;
  int sel = 0;
  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.stock,
    required this.image,
    required this.description,
    required this.price,
    required this.mrp,
    required this.rating,
    required this.views,
    required this.colors,
    required this.spec,
  });

  factory Product.from(J p) {
    final price = numOf(p['price'], 0);
    final mrp0 = numOf(p['mrp'], 0);
    final colors = <J>[];
    for (final x in (p['colors'] is List ? p['colors'] as List : const [])) {
      if (x is Map && RegExp(r'^#[0-9a-f]{3,8}$', caseSensitive: false).hasMatch('${x['h'] ?? ''}'.trim())) {
        colors.add(Map<String, dynamic>.from(x));
      }
    }
    final spec = <List<String>>[];
    for (final x in (p['spec'] is List ? p['spec'] as List : const [])) {
      if (x is List && x.length >= 2 && ('${x[0]}'.trim().isNotEmpty || '${x[1]}'.trim().isNotEmpty)) {
        spec.add(['${x[0]}', '${x[1]}']);
      }
    }
    final id = numOf(p['id'], 0).toInt();
    if (spec.isEmpty) {
      final d = demoSpec['$id'];
      if (d is List) {
        for (final x in d) {
          spec.add(['${x[0]}', '${x[1]}']);
        }
      }
    }
    return Product(
      id: id,
      name: '${p['name'] ?? ''}',
      brand: '${p['brand'] ?? ''}',
      category: '${p['category'] ?? ''}',
      stock: '${p['stock'] ?? ''}',
      image: '${p['image'] ?? ''}',
      description: '${p['description'] ?? ''}',
      price: price,
      mrp: mrp0 == 0 ? price : mrp0,
      rating: numOf(p['rating'], 4.5),
      views: numOf(p['views'], 0).toInt(),
      colors: colors,
      spec: spec,
    );
  }

  int get off => mrp > 0 ? ((1 - price / mrp) * 100).round() : 0;
}

class Coupon {
  final String c, t, d, type;
  final num min, val;
  final bool pm, fa;
  Coupon(this.c, this.t, this.d, this.type, this.min, this.val, this.pm, this.fa);
  num amt(num s) => type == 'pct' ? (s * val / 100).round() : val;
}

class Rules {
  num free, fee, pf, cut;
  Map<String, List<num>> eta;
  List<num> n, p, pct;
  Rules(this.free, this.fee, this.pf, this.cut, this.eta, this.n, this.p, this.pct);

  static List<num> _pair(dynamic v, num a, num b) {
    if (v is List && v.length >= 2) return [numOf(v[0], a), numOf(v[1], b)];
    return [a, b];
  }

  factory Rules.from(dynamic r) {
    final m = r is Map ? r : <String, dynamic>{};
    final e = m['eta'] is Map ? m['eta'] as Map : <String, dynamic>{};
    return Rules(
      numOf(m['free'], 999),
      numOf(m['fee'], 49),
      numOf(m['pf'], 2),
      numOf(m['cut'], 17),
      {'m': _pair(e['m'], 3, 4), 's': _pair(e['s'], 5, 7), 'r': _pair(e['r'], 8, 10)},
      _pair(m['n'], 1299, 2599),
      _pair(m['p'], 799, 1499),
      _pair(m['pct'], 10, 15),
    );
  }
}

class Totals {
  num sub = 0, mrp = 0, pd = 0, auto = 0, couponDisc = 0, disc = 0, ship = 0, total = 0, gst = 0, cgst = 0, sgst = 0, tax = 0;
  int n = 0;
  String kind = '', cc = '';
  bool pr = false;
  Totals();
  J toJson() => {
        'sub': sub, 'mrp': mrp, 'pd': pd, 'auto': auto, 'couponDisc': couponDisc, 'disc': disc, 'ship': ship, 'total': total,
        'gst': gst, 'cgst': cgst, 'sgst': sgst, 'tax': tax, 'n': n, 'kind': kind, 'cc': cc, 'pr': pr,
      };
  factory Totals.fromJson(dynamic m0) {
    final m = m0 is Map ? m0 : <String, dynamic>{};
    final t = Totals();
    t.sub = numOf(m['sub']);
    t.mrp = numOf(m['mrp']);
    t.pd = numOf(m['pd']);
    t.auto = numOf(m['auto']);
    t.couponDisc = numOf(m['couponDisc']);
    t.disc = numOf(m['disc']);
    t.ship = numOf(m['ship']);
    t.total = numOf(m['total']);
    t.gst = numOf(m['gst']);
    t.cgst = numOf(m['cgst']);
    t.sgst = numOf(m['sgst']);
    t.tax = numOf(m['tax']);
    t.n = numOf(m['n']).toInt();
    t.kind = '${m['kind'] ?? ''}';
    t.cc = '${m['cc'] ?? ''}';
    t.pr = m['pr'] == true;
    return t;
  }
}

// ───────── app state ─────────
class AppState extends ChangeNotifier {
  late SharedPreferences prefs;

  // configuration (what the admin edits)
  J base = {};
  J cfg = {};
  J? liveRaw; // published / saved config, raw
  Map<String, String> vars = {};
  String fontH = '', fontB = '';
  Rules ru = Rules.from({});
  List<Product> P = [];
  List<List<String>> cats = [['All', '◫']];
  List<String> brands = [];
  List<Coupon> coupons = [];
  List<J> slides = [];
  List<J> textRules = [];
  List<String> admins = [];
  bool storeOpen = true;
  String razorKey = '';
  bool rzpOn = false, codOn = true;
  final Set<String> seenTexts = {};

  // customer data (stored on the phone)
  Map<String, J> cart = {};
  Set<int> wish = {};
  List<J> orders = [];
  J? user;
  List<J> users = [];
  String coupon = '';
  String pm = 'cod';
  String pin = '';
  J addr = {};
  bool notif = true;
  Map<String, J> pinc = {};
  Map<String, dynamic> reviews = {};
  List<int> recent = [];

  // home screen filters
  String cat = 'All', brand = '', term = '', sort = 'feat';
  num fMin = 0, fMax = 99999, fR = 0, fD = 0;
  String after = '';
  VoidCallback? goShopCb;
  Timer? _tick;

  // ───────── init ─────────
  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    base = clone(baseConfig) as J;
    final live = ls('live', null);
    liveRaw = live is Map ? Map<String, dynamic>.from(live) : null;
    applyCfg(liveRaw ?? {}, notify: false);

    final c = ls('cart', {});
    if (c is Map) {
      for (final e in c.entries) {
        if (e.value is Map) cart['${e.key}'] = Map<String, dynamic>.from(e.value as Map);
      }
    }
    final w = ls('wish', []);
    if (w is List) wish = {for (final x in w) numOf(x).toInt()};
    final o = ls('orders2', []);
    if (o is List) orders = [for (final x in o) if (x is Map) Map<String, dynamic>.from(x)];
    final u = ls('user', null);
    user = u is Map ? Map<String, dynamic>.from(u) : null;
    final us = ls('users', null);
    if (us is List && us.isNotEmpty) {
      users = [for (final x in us) if (x is Map) Map<String, dynamic>.from(x)];
    } else {
      users = [
        {'n': 'Demo Shopper', 'e': 'demo.shopper@gmail.com', 'pw': 'demo1234', 'prime': false},
        {'n': 'Riya Patel', 'e': 'riya.patel.demo@gmail.com', 'pw': 'prime1234', 'prime': true},
      ];
    }
    final a = ls('addr', {});
    addr = a is Map ? Map<String, dynamic>.from(a) : {};
    pin = '${ls('pin', '')}';
    notif = ls('notif', 1) != 0;
    final pc = ls('pinc', {});
    if (pc is Map) {
      for (final e in pc.entries) {
        if (e.value is Map) pinc['${e.key}'] = Map<String, dynamic>.from(e.value as Map);
      }
    }
    final rv = ls('reviews', {});
    reviews = rv is Map ? Map<String, dynamic>.from(rv) : {};
    final rc = ls('rvw', []);
    if (rc is List) recent = [for (final x in rc) numOf(x).toInt()];
    pm = '${ls('pm', 'cod')}';
    if (pm != 'razorpay') pm = 'cod';
    _fixPm();

    _tick = Timer.periodic(const Duration(seconds: 2), (_) => _orderTick());
  }

  // ───────── storage helpers ─────────
  dynamic ls(String k, dynamic d) {
    final s = prefs.getString('rm_$k');
    if (s == null) return d;
    try {
      final v = jsonDecode(s);
      return v ?? d;
    } catch (_) {
      return d;
    }
  }

  void lsSet(String k, dynamic v) {
    prefs.setString('rm_$k', jsonEncode(v));
  }

  void saveCart() {
    lsSet('cart', cart);
    lsSet('wish', wish.toList());
  }

  void saveOrders() => lsSet('orders2', orders);
  void saveUsers() => lsSet('users', users);
  void saveUser() => lsSet('user', user);

  void refresh() => notifyListeners();

  // ───────── config ─────────
  /// Apply a (partial) config on top of the defaults. Same job as apply() in the website's bridge.
  void applyCfg(Map c, {bool notify = true}) {
    cfg = merge(base, c) as J;
    final r = Rules.from(cfg['rules']);
    ru = r;

    final list = <Product>[];
    for (final p in (cfg['products'] as List)) {
      if (p is Map && truthy(p['active'])) list.add(Product.from(Map<String, dynamic>.from(p)));
    }
    // keep chosen colours when the list is rebuilt
    for (final p in list) {
      for (final o in P) {
        if (o.id == p.id && o.sel < p.colors.length) p.sel = o.sel;
      }
    }
    P = list;

    final cs = <String>{};
    for (final p in P) {
      if (p.category.isNotEmpty) cs.add(p.category);
    }
    cats = [
      ['All', '◫']
    ];
    var i = 0;
    for (final k in cs) {
      cats.add([k, catIcons[i % catIcons.length]]);
      i++;
    }
    final bs = <String>{};
    for (final p in P) {
      if (p.brand.isNotEmpty) bs.add(p.brand);
    }
    brands = bs.toList();

    coupons = [];
    for (final x in (cfg['coupons'] as List)) {
      if (x is Map && truthy(x['active']) && '${x['c'] ?? ''}'.trim().isNotEmpty) {
        coupons.add(Coupon('${x['c']}'.trim().toUpperCase(), '${x['t'] ?? ''}', '${x['d'] ?? ''}', '${x['type']}', numOf(x['min'], 0), numOf(x['val'], 0), truthy(x['pm']), truthy(x['fa'])));
      }
    }

    slides = [];
    for (final s in (cfg['slides'] as List)) {
      if (s is! Map) continue;
      final img = numOf(s['img'], 0).toInt();
      final ok = P.any((p) => p.id == img);
      slides.add({
        'bg': '${s['bg'] ?? ''}',
        'dark': truthy(s['dark']),
        'tag': '${s['tag'] ?? ''}',
        'h': '${s['h'] ?? ''}',
        'p': '${s['p'] ?? ''}',
        'img': ok ? img : (P.isNotEmpty ? P.first.id : 0),
        'badge': '${s['badge'] ?? ''}',
        'deal': '${s['deal'] ?? ''}',
        'off': '${s['off'] ?? ''}',
        'offl': '${s['offl'] ?? ''}',
        'cta': '${s['cta'] ?? ''}',
        'target': '${s['target'] ?? 'All'}',
      });
    }

    final th = cfg['theme'] is Map ? cfg['theme'] as Map : <String, dynamic>{};
    vars = {};
    final tv = th['vars'] is Map ? th['vars'] as Map : <String, dynamic>{};
    for (final e in tv.entries) {
      if ('${e.value}'.trim().isNotEmpty) vars['${e.key}'] = '${e.value}'.trim();
    }
    fontH = '${th['fontH'] ?? ''}'.replaceAll(RegExp(r'[^\w ]'), '').trim();
    fontB = '${th['fontB'] ?? ''}'.replaceAll(RegExp(r'[^\w ]'), '').trim();

    textRules = [];
    for (final x in (cfg['text'] is List ? cfg['text'] as List : const [])) {
      if (x is Map && '${x['f'] ?? ''}'.isNotEmpty && x['r'] != null) textRules.add(Map<String, dynamic>.from(x));
    }
    admins = [for (final x in (cfg['admins'] is List ? cfg['admins'] as List : const [])) if ('$x'.trim().isNotEmpty) '$x'.toLowerCase()];
    storeOpen = !(cfg['open'] == false || cfg['open'] == 0 || cfg['open'] == '0');

    final pay = cfg['pay'] is Map ? cfg['pay'] as Map : <String, dynamic>{};
    rzpOn = truthy(pay['rzp']);
    codOn = truthy(pay['cod']);
    final k = '${pay['key'] ?? ''}'.trim();
    razorKey = rzpOn ? (k.isNotEmpty ? k : razorpayKeyId) : '';
    if (cat != 'All' && !cats.any((e) => e[0] == cat)) cat = 'All';
    if (brand.isNotEmpty && !brands.contains(brand)) brand = '';
    _fixPm();
    if (notify) notifyListeners();
  }

  void _fixPm() {
    if (pm == 'razorpay' && !rzpOn) pm = 'cod';
    if (pm == 'cod' && !codOn && rzpOn) pm = 'razorpay';
  }

  void restoreLive() => applyCfg(liveRaw ?? {});

  // ───────── colours from the theme ─────────
  Color _col(String k, Color d) => parseColor(vars[k] ?? '') ?? d;
  Color get ink => _col('--ink', const Color(0xFF111215));
  Color get mut => _col('--mut', const Color(0xFF6B6F78));
  Color get paper => _col('--paper', const Color(0xFFF1F2F4));
  Color get line => _col('--line', const Color(0xFFDFE1E6));
  Color get rust => _col('--rust', const Color(0xFFA8741A));
  LinearGradient _g(String k, List<Color> fb) => parseGradient(vars[k] ?? '', vars) ?? LinearGradient(colors: fb, begin: Alignment.topLeft, end: Alignment.bottomRight);
  LinearGradient get gd => _g('--gd', const [Color(0xFF0E0F11), Color(0xFF24272C), Color(0xFF4B5058)]);
  LinearGradient get gg => _g('--gg', const [Color(0xFFF6E7B8), Color(0xFFE0B95F)]);
  LinearGradient get gl => _g('--gl', const [Color(0xFFF8F9FB), Color(0xFFE6E8EC), Color(0xFFD4D7DD)]);
  LinearGradient get gc => _g('--gc', const [Color(0xFFF8F0D8), Color(0xFFE9D6A0)]);
  LinearGradient get gyl => _g('--gyl', const [Color(0xFFFFFBE6), Color(0xFFF4DD92)]);
  LinearGradient get gwg => _g('--gwg', const [Color(0xFFFFFFFF), Color(0xFFE6E8ED)]);
  LinearGradient get gpk => _g('--gpk', const [Color(0xFFFFF0F5), Color(0xFFFBC9DC)]);
  LinearGradient get gor => _g('--gor', const [Color(0xFFFFF3E4), Color(0xFFFFC9A0)]);
  LinearGradient gradOf(String css) => parseGradient(css, vars) ?? gl;

  // ───────── text replacement (Edit any text) ─────────
  String tx(String s) {
    if (s.length > 2 && s.length < 160 && RegExp(r'[A-Za-z]').hasMatch(s)) seenTexts.add(s.replaceAll(RegExp(r'\s+'), ' ').trim());
    if (textRules.isEmpty) return s;
    var o = s;
    for (final x in textRules) {
      final f = '${x['f']}';
      if (o.contains(f)) o = o.split(f).join('${x['r']}');
    }
    return o;
  }

  // ───────── products ─────────
  Product? prod(dynamic id) {
    final i = numOf(id).toInt();
    for (final p in P) {
      if (p.id == i) return p;
    }
    return null;
  }

  List<Product> filtered() {
    final q = term.trim().toLowerCase();
    final l = P.where((p) {
      if (cat != 'All' && p.category != cat) return false;
      if (brand.isNotEmpty && p.brand != brand) return false;
      if (p.price < fMin || p.price > fMax) return false;
      if (p.rating < fR) return false;
      if (p.off < fD) return false;
      return '${p.name} ${p.brand} ${p.category}'.toLowerCase().contains(q);
    }).toList();
    switch (sort) {
      case 'price':
        l.sort((a, b) => a.price.compareTo(b.price));
        break;
      case '-price':
        l.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        l.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'deal':
        l.sort((a, b) => b.off.compareTo(a.off));
        break;
      case 'name':
        l.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'popular':
        l.sort((a, b) => b.views.compareTo(a.views));
        break;
    }
    return l;
  }

  List<Product> trending() {
    final l = [...P];
    l.sort((a, b) => b.views.compareTo(a.views));
    return l.take(5).toList();
  }

  void resetFilters() {
    cat = 'All';
    brand = '';
    term = '';
    fMin = 0;
    fMax = 99999;
    fR = 0;
    fD = 0;
    notifyListeners();
  }

  void goShop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      goShopCb?.call();
    });
  }

  // ───────── user / prime ─────────
  bool get isPrime {
    final u = user;
    if (u == null || u['prime'] != true) return false;
    final pu = u['primeUntil'];
    return pu == null || pu == 0 || numOf(pu) > nowMs();
  }

  bool get isAdmin => user != null && admins.contains('${user!['e']}'.toLowerCase());

  // ───────── cart ─────────
  int get cartCount => cart.values.fold<int>(0, (a, b) => a + (b['q'] as int));

  void addItem(int id, String size, int n) {
    final k = '$id|$size';
    cart.putIfAbsent(k, () => {'id': id, 'size': size, 'q': 0});
    cart[k]!['q'] = (cart[k]!['q'] as int) + n;
    saveCart();
    notifyListeners();
  }

  void qty(String k, int d) {
    final it = cart[k];
    if (it == null) return;
    it['q'] = (it['q'] as int) + d;
    if ((it['q'] as int) <= 0) cart.remove(k);
    saveCart();
    notifyListeners();
  }

  void toggleWish(int id) {
    if (!wish.remove(id)) wish.add(id);
    saveCart();
    notifyListeners();
  }

  void saveLater(String k) {
    final it = cart[k];
    if (it == null) return;
    wish.add(it['id'] as int);
    cart.remove(k);
    saveCart();
    notifyListeners();
  }

  void pruneCart() {
    final bad = cart.entries.where((e) => prod(e.value['id']) == null).map((e) => e.key).toList();
    for (final k in bad) {
      cart.remove(k);
    }
  }

  num memberDiscount(num sub) {
    final t = isPrime ? ru.p : ru.n;
    if (sub > t[1]) return (sub * ru.pct[1] / 100).round();
    if (sub > t[0]) return (sub * ru.pct[0] / 100).round();
    return 0;
  }

  num couponAmt(String code, num sub) {
    Coupon? c;
    for (final x in coupons) {
      if (x.c == code) c = x;
    }
    if (c == null || sub < c.min || (c.pm && !isPrime)) return 0;
    if (c.fa) {
      final has = cart.values.any((i) => prod(i['id'])?.category == 'Fashion');
      if (!has) return 0;
    }
    return math.min(c.amt(sub), sub);
  }

  Totals totals() {
    num sub = 0, mrp = 0;
    var n = 0;
    final lines = <List<num>>[];
    for (final it in cart.values) {
      final p = prod(it['id']);
      if (p == null) continue;
      final q = it['q'] as int;
      final a = p.price * q;
      sub += a;
      mrp += p.mrp * q;
      n += q;
      lines.add([a, gstRates[p.category] ?? 18]);
    }
    final auto = memberDiscount(sub);
    final cd = couponAmt(coupon, sub);
    final disc = math.max(auto, cd);
    final kind = disc == 0 ? '' : (cd >= auto && cd > 0 ? 'coupon' : 'member');
    final ship = (sub == 0 || sub >= ru.free || isPrime) ? 0 : ru.fee;
    num gst0 = 0;
    for (final l in lines) {
      final net = l[0] * (sub > 0 ? 1 - disc / sub : 1);
      gst0 += net - net / (1 + l[1] / 100);
    }
    final g = gst0.round();
    final cg = (g / 2).floor();
    final t = Totals();
    t.sub = sub;
    t.mrp = mrp;
    t.n = n;
    t.pd = mrp - sub;
    t.auto = auto;
    t.couponDisc = cd;
    t.disc = disc;
    t.kind = kind;
    t.ship = ship;
    t.total = sub - disc + ship;
    t.gst = g;
    t.cgst = cg;
    t.sgst = g - cg;
    t.tax = sub - disc - g;
    t.cc = coupon;
    t.pr = isPrime;
    return t;
  }

  // ───────── orders ─────────
  int stage(J o) {
    if (o['x'] == 1 || o['x'] == true) return -1;
    return math.min(3, ((nowMs() - numOf(o['date']).toInt()) / 30000).floor());
  }

  J? orderById(String id) {
    for (final o in orders) {
      if (o['id'] == id) return o;
    }
    return null;
  }

  String itemName(dynamic i) {
    final p = prod(i['id']);
    final q = numOf(i['q']).toInt();
    return (p?.name ?? '${i['pn'] ?? 'Item'}') + (q > 1 ? ' ×$q' : '');
  }

  int activeOrders() => orders.where((o) => stage(o) >= 0 && stage(o) < 3).length;

  void _orderTick() {
    var ch = false;
    for (final o in orders) {
      final s = stage(o);
      if (s > numOf(o['n0']).toInt()) {
        o['n0'] = s;
        ch = true;
        if (notif) onToast?.call('${o['id']}: ${stageLabels[s]}');
      }
    }
    if (ch) {
      saveOrders();
      notifyListeners();
    }
  }

  void Function(String)? onToast;

  void resetDemo() {
    orders = [];
    cart = {};
    coupon = '';
    saveOrders();
    saveCart();
    notifyListeners();
  }

  // ───────── reviews ─────────
  List<J> myReviews(int id) {
    final l = reviews['$id'];
    if (l is! List) return [];
    return [for (final x in l) if (x is Map) Map<String, dynamic>.from(x)];
  }

  List<J> allReviews(int id) {
    final out = myReviews(id);
    for (final v in demoReviews) {
      out.add({'n': v[0], 'r': v[2], 't': v[1], 's': 1});
    }
    return out;
  }

  void setPm(String k) {
    pm = k;
    lsSet('pm', k);
    notifyListeners();
  }

  void rememberViewed(int id) {
    recent = [id, ...recent.where((x) => x != id)].take(8).toList();
    lsSet('rvw', recent);
  }
}
