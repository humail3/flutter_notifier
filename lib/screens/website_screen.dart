import 'package:flutter/material.dart';
import 'package:notifier/constants.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WesbiteScreen extends StatefulWidget {
  const WesbiteScreen({super.key});

  static const String id = "website_screen";

  @override
  State<WesbiteScreen> createState() => _WesbiteScreenState();
}

class _WesbiteScreenState extends State<WesbiteScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

 @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
              setState(() {
                _isLoading = progress < 100;
              });
            print('WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onHttpError: (HttpResponseError error) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://api.notrufnoe.at/c9/status.php')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://api.notrufnoe.at/c9/status.php'));

 }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Website',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Stack(children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            kSpinKitDoubleBounce,
        ]),
      ),
    );
  }
}
