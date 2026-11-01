import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'config.dart';
import 'core.dart';
import 'state.dart';

// ───────── PIN / delivery engine (Meesho-style date ranges) ─────────
const _metro = {'11', '12', '20', '40', '41', '56', '60', '70', '50', '38', '30', '22'};
const _stateRanges = [
  (11, 11, 'Delhi'), (12, 13, 'Haryana'), (14, 16, 'Punjab'), (17, 17, 'Himachal Pradesh'), (18, 19, 'Jammu & Kashmir'),
  (20, 28, 'Uttar Pradesh / Uttarakhand'), (30, 34, 'Rajasthan'), (36, 39, 'Gujarat'), (40, 44, 'Maharashtra'),
  (45, 48, 'Madhya Pradesh'), (49, 49, 'Chhattisgarh'), (50, 53, 'Telangana / Andhra Pradesh'), (56, 59, 'Karnataka'),
  (60, 66, 'Tamil Nadu'), (67, 69, 'Kerala'), (70, 74, 'West Bengal'), (75, 77, 'Odisha'), (78, 78, 'Assam'),
  (79, 79, 'North East'), (80, 85, 'Bihar / Jharkhand'),
];

bool okPin(String p) => RegExp(r'^[1-9]\d{5}$').hasMatch(p);

String stateOf(String p) {
  final n = int.tryParse(p.length >= 2 ? p.substring(0, 2) : '') ?? 0;
  for (final r in _stateRanges) {
    if (n >= r.$1 && n <= r.$2) return r.$3;
  }
  return 'India';
}

Future<J> lookupPin(String pin) async {
  final c = app.pinc[pin];
  if (c != null) return c;
  try {
    final r = await http.get(Uri.parse('https://api.postalpincode.in/pincode/$pin')).timeout(const Duration(seconds: 10));
    final j = jsonDecode(r.body);
    final r0 = (j is List && j.isNotEmpty) ? j[0] : null;
    if (r0 is Map && r0['Status'] == 'Success' && r0['PostOffice'] is List && (r0['PostOffice'] as List).isNotEmpty) {
      final po = r0['PostOffice'] as List;
      final o = po[0] as Map;
      app.pinc[pin] = {
        'ok': 1,
        'area': '${o['Name']}',
        'dist': '${o['District']}',
        'state': '${o['State']}',
        'more': [for (final x in po.skip(1).take(3)) '${(x as Map)['Name']}'],
      };
      app.lsSet('pinc', app.pinc);
    } else if (r0 is Map && r0['Status'] == 'Error') {
      app.pinc[pin] = {'ok': 0};
      app.lsSet('pinc', app.pinc);
    }
  } catch (_) {}
  return app.pinc[pin] ?? {'ok': -1};
}

({num lo, num hi, String n}) zone(String p) {
  final i = app.pinc[p];
  final v = i != null && i['ok'] == 1;
  final st = v ? '${i!['state']}' : stateOf(p);
  final loc = v ? '${i!['dist']} ${i['area']}' : '';
  final isMetro = v
      ? RegExp(r'mumbai|delhi|bengaluru|bangalore|chennai|kolkata|hyderabad|pune|ahmedabad|thane|gurugram|gurgaon|noida|ghaziabad', caseSensitive: false).hasMatch(loc)
      : _metro.contains(p.substring(0, 2));
  if (isMetro) return (lo: app.ru.eta['m']![0], hi: app.ru.eta['m']![1], n: 'Metro');
  if (RegExp(r'jammu|kashmir|ladakh|assam|arunachal|nagaland|manipur|mizoram|tripura|meghalaya|sikkim|andaman|lakshadweep|north east', caseSensitive: false).hasMatch(st)) {
    return (lo: app.ru.eta['r']![0], hi: app.ru.eta['r']![1], n: 'Remote');
  }
  return (lo: app.ru.eta['s']![0], hi: app.ru.eta['s']![1], n: 'Standard');
}

String etaRange(String pin, bool pr) {
  final z = zone(pin);
  num lo = z.lo, hi = z.hi;
  if (pr) {
    lo = math.max(1, lo - app.ru.pf);
    hi = math.max(lo + 1, hi - app.ru.pf);
  }
  final late = DateTime.now().hour >= app.ru.cut ? 1 : 0;
  String f(num n) => dShort(DateTime.now().add(Duration(days: n.toInt() + late)));
  return '${f(lo)} – ${f(hi)}';
}

String etaText(String pin) => okPin(pin) ? 'Delivery by ${etaRange(pin, app.isPrime)}${app.isPrime ? ' · Prime fast delivery' : ''}' : 'Enter your PIN code to see the delivery date.';

String locLine(String pin) {
  final i = app.pinc[pin];
  if (i != null && i['ok'] == 1) return '${i['area']}, ${i['dist']}, ${i['state']} – $pin';
  return '${stateOf(pin)} region – $pin';
}

// ───────── location ─────────
class GeoResult {
  final String? error;
  final String addr, pin, mapUrl;
  GeoResult({this.error, this.addr = '', this.pin = '', this.mapUrl = ''});
}

Future<GeoResult> locateMe() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return GeoResult(error: 'Location is turned off. Enter your PIN.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return GeoResult(error: 'Location permission denied. Enter your PIN instead.');
    }
    final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)));
    final la = pos.latitude, lo = pos.longitude;
    var addr = '', pin = '';
    try {
      final key = '${gp(app.cfg, 'api.gmaps') ?? ''}'.trim();
      if (key.isNotEmpty) {
        final r = await http.get(Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?latlng=$la,$lo&key=$key')).timeout(const Duration(seconds: 10));
        final j = jsonDecode(r.body);
        final res = j['results'];
        if (res is List && res.isNotEmpty) {
          final c = res[0] as Map;
          addr = '${c['formatted_address'] ?? ''}';
          for (final x in (c['address_components'] as List)) {
            if ((x['types'] as List).contains('postal_code')) pin = '${x['long_name']}';
          }
        }
      } else {
        final r = await http.get(Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$la&lon=$lo'), headers: {'User-Agent': 'RealisticMartApp/1.0'}).timeout(const Duration(seconds: 10));
        final j = jsonDecode(r.body);
        addr = '${j['display_name'] ?? ''}';
        final a = j['address'];
        if (a is Map) pin = '${a['postcode'] ?? ''}'.replaceAll(RegExp(r'\s'), '');
      }
    } catch (_) {}
    return GeoResult(addr: addr, pin: pin, mapUrl: 'https://www.google.com/maps?q=$la,$lo');
  } catch (_) {
    return GeoResult(error: 'Could not access location. Allow location permission or enter your PIN.');
  }
}

Future<void> openUrl(String u) async {
  try {
    await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

// ───────── Supabase (REST) ─────────
bool get hasSupabase => supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
String get sbBase => supabaseUrl.trim().replaceAll(RegExp(r'/$'), '');

Map<String, String> sbHeaders([String? token]) {
  final h = <String, String>{'apikey': supabaseAnonKey.trim()};
  final bearer = token ?? (supabaseAnonKey.trim().startsWith('eyJ') ? supabaseAnonKey.trim() : null);
  if (bearer != null) h['Authorization'] = 'Bearer $bearer';
  return h;
}

/// Published settings: Supabase first, then site.json link.
Future<J?> fetchRemoteConfig() async {
  if (hasSupabase) {
    try {
      final r = await http.get(Uri.parse('$sbBase/rest/v1/$settingsTable?id=eq.main&select=data'), headers: sbHeaders()).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final a = jsonDecode(r.body);
        if (a is List && a.isNotEmpty && a[0] is Map) {
          final d = (a[0] as Map)['data'];
          if (d is Map && d['v'] != null) return Map<String, dynamic>.from(d);
        }
      }
    } catch (_) {}
  }
  if (siteJsonUrl.trim().isNotEmpty) {
    try {
      final sep = siteJsonUrl.contains('?') ? '&' : '?';
      final r = await http.get(Uri.parse('${siteJsonUrl.trim()}$sep${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        if (j is Map && j['v'] != null) return Map<String, dynamic>.from(j);
      }
    } catch (_) {}
  }
  return null;
}

Future<void> loadRemoteConfig() async {
  final j = await fetchRemoteConfig();
  if (j != null) {
    app.liveRaw = j;
    app.lsSet('live', j);
    app.applyCfg(j);
  }
}

Future<void> sendOrder(J o) async {
  if (!hasSupabase) return;
  try {
    final r = await http
        .post(Uri.parse('$sbBase/rest/v1/$ordersTable'),
            headers: {...sbHeaders(), 'Content-Type': 'application/json', 'Prefer': 'return=minimal'}, body: jsonEncode({'id': o['id'], 'data': o}))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode >= 200 && r.statusCode < 300) {
      o['_sent'] = 1;
      app.saveOrders();
    }
  } catch (_) {}
}

// ───────── Razorpay checkout (runs the official checkout.js in a web view) ─────────
class RazorpayPage extends StatefulWidget {
  final String key0, name, email, phone;
  final int amountPaise;
  const RazorpayPage({super.key, required this.key0, required this.name, required this.email, required this.phone, required this.amountPaise});
  @override
  State<RazorpayPage> createState() => _RazorpayState();
}

class _RazorpayState extends State<RazorpayPage> {
  late final WebViewController ctrl;
  bool done = false;

  void finish(Map<String, dynamic> r) {
    if (done || !mounted) return;
    done = true;
    Navigator.of(context).pop(r);
  }

  @override
  void initState() {
    super.initState();
    final opts = {
      'key': widget.key0,
      'amount': widget.amountPaise,
      'currency': 'INR',
      'name': app.cfg['brand'] is Map ? '${app.cfg['brand']['name']}' : 'Realistic Mart',
      'description': 'Order payment',
      'prefill': {'name': widget.name, 'email': widget.email, 'contact': widget.phone},
      'theme': {'color': '#15161a'},
    };
    final html = '''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:sans-serif;display:grid;place-items:center;height:100vh;margin:0;background:#f4f5f8;color:#111}</style></head>
<body><p>Opening secure payment…</p>
<script src="https://checkout.razorpay.com/v1/checkout.js"></script>
<script>
var OPTS = ${jsonEncode(opts)};
function send(o){ Rzp.postMessage(JSON.stringify(o)); }
window.onload = function(){
  try {
    OPTS.handler = function(r){ send({t:'ok', id: r.razorpay_payment_id}); };
    OPTS.modal = { ondismiss: function(){ send({t:'dismiss'}); } };
    var rz = new Razorpay(OPTS);
    rz.on('payment.failed', function(r){ send({t:'fail', m: (r && r.error && r.error.description) || ''}); });
    rz.open();
  } catch(e) { send({t:'err', m: String(e)}); }
};
</script></body></html>''';
    ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Rzp', onMessageReceived: (m) {
        try {
          final j = jsonDecode(m.message);
          if (j is Map) finish(Map<String, dynamic>.from(j));
        } catch (_) {}
      })
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (req) {
        final u = Uri.tryParse(req.url);
        if (u != null && !['http', 'https', 'about', 'data', 'blob', 'javascript'].contains(u.scheme)) {
          launchUrl(u, mode: LaunchMode.externalApplication).catchError((_) => false);
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      }))
      ..loadHtmlString(html, baseUrl: 'https://razorpay.com');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Secure payment'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => finish({'t': 'dismiss'})),
        ),
        body: SafeArea(child: WebViewWidget(controller: ctrl)),
      );
}
