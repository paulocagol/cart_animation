import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import 'page.dart';

Future<void> main() async {
  runApp(DevicePreview(
    enabled: true,
    builder: (context) => const App(),
  ));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      title: 'Device Preview Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ShopPage(),
    );
  }
}
