import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const ZenvoraApp());

class ZenvoraApp extends StatelessWidget {
  const ZenvoraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Zenvora',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xffb98b36)),
    home: const StoreShell(),
  );
}

class StoreShell extends StatefulWidget {
  const StoreShell({super.key});
  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  late final WebViewController _controller;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xfff1f2f4))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadFlutterAsset('assets/web/index.html');
  }

  Future<void> _openAdmin() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPage()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Zenvora'),
      actions: [IconButton(tooltip: 'Admin panel', onPressed: _openAdmin, icon: const Icon(Icons.admin_panel_settings_outlined))],
    ),
    body: Stack(children: [
      WebViewWidget(controller: _controller),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
    ]),
  );
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late final WebViewController _controller;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xfff4f5f7))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadFlutterAsset('assets/web/admin.html');
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Zenvora Admin')),
    body: Stack(children: [
      WebViewWidget(controller: _controller),
      if (_loading) const LinearProgressIndicator(minHeight: 2),
    ]),
  );
}
