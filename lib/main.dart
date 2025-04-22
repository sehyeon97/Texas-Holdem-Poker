import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:street_fighter/bluetooth/server.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
  ]);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker Server',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: PreferredSize(
            // change height of app bar
            preferredSize: const Size.fromHeight(20.0),
            child: AppBar(
              title: const Text('Texas Hold \'em'),
              centerTitle: true,
            )),
        body: const PokerBluetoothManager(),
      ),
    );
  }
}
