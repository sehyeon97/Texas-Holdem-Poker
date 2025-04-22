// Dart Imports
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';

// Package Imports
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:street_fighter/screen/game.dart';

// // Constants
// const String BLERemoteServiceUUID = "62154268-5851-4fb5-89c7-a1f925cd3f7e";

const String targetDeviceName = "Poker"; // this is what the M5s will see
const String playerOneID = "Player1";
const String playerTwoID = "Player2";
const String playerThreeID = "Player3";
const String playerFourID = "Player4";
const int numOfDevicesToConnectTo = 0;

List<Guid> characteristicUUIDs = [
  Guid("3c479062-fca6-4e2b-8812-172a47615aff"), // Game state
  Guid("4b727791-ab46-4d97-84fd-c1ea9aee6b74"), // Winner
  Guid("710c29f5-bc94-424b-a80f-7ac6d7b1e503"), // Current bet
  Guid("c819b023-58d4-446a-8d8f-08e62ed260eb"), // Player cards
  Guid("ad58c34d-1024-4ecd-adb1-6bfaa4d90b96"), // Player bet
  Guid("6b050126-2bd9-4b6f-9a30-aed591d606dd"), // Player visibility
];

class M5Device {
  final BluetoothDevice device;
  Map<Guid, BluetoothCharacteristic> characteristics = {};

  M5Device(this.device);
}

class PokerBluetoothManager extends StatefulWidget {
  const PokerBluetoothManager({super.key});

  @override
  State<StatefulWidget> createState() {
    return _PokerBluetoothManagerState();
  }
}

class _PokerBluetoothManagerState extends State<PokerBluetoothManager> {
  final FlutterBluePlus flutterBlue = FlutterBluePlus();
  final List<M5Device> connectedDevices = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> scanAndConnectToDevices(BuildContext context) async {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult result in results) {
        if ((result.device.platformName == playerOneID ||
                result.device.platformName == playerTwoID ||
                result.device.platformName == playerThreeID ||
                result.device.platformName == playerFourID) &&
            !_alreadyConnected(result.device)) {
          await FlutterBluePlus.stopScan();
          print("Connecting to: ${result.device.remoteId.str}");
          await result.device.connect(autoConnect: false);
          final m5 = M5Device(result.device);
          await _discoverServicesAndChars(m5);
          connectedDevices.add(m5);

          if (connectedDevices.length >= numOfDevicesToConnectTo) {
            // Navigate to main screen when all 4 M5s are connected
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => GameScreen(
                        devices: connectedDevices,
                        sendBet: sendBet,
                        readBet: readBet,
                        readPlayerVis: readPlayerVis,
                        writeWinner: writeWinner,
                        readGameState: readGameState,
                        writeGameState: writeGameState,
                        writePlayerCards: writePlayerCards,
                      )),
            );
          } else {
            FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
          }
        }
      }
    });
  }

  bool _alreadyConnected(BluetoothDevice device) {
    return connectedDevices
        .any((d) => d.device.remoteId.str == device.remoteId.str);
  }

  Future<void> _discoverServicesAndChars(M5Device m5) async {
    List<BluetoothService> services = await m5.device.discoverServices();
    for (var service in services) {
      for (var char in service.characteristics) {
        if (characteristicUUIDs.contains(char.uuid)) {
          m5.characteristics[char.uuid] = char;

          // Optionally listen to notifications:
          if (char.properties.notify) {
            await char.setNotifyValue(true);
            char.lastValueStream.listen((value) {
              print("Notification from ${char.uuid}: ${utf8.decode(value)}");
            });
          }
        }
      }
    }
  }

  Future<void> sendBet(BluetoothCharacteristic characteristic, int bet) async {
    final bytes = ByteData(4)..setInt32(0, bet, Endian.little);
    await characteristic.write(bytes.buffer.asUint8List());
  }

  Future<int?> readBet(BluetoothCharacteristic characteristic) async {
    final value = await characteristic.read();
    return ByteData.sublistView(Uint8List.fromList(value))
        .getInt32(0, Endian.little);
  }

  Future<int?> readPlayerVis(BluetoothCharacteristic characteristic) async {
    final value = await characteristic.read();
    return ByteData.sublistView(Uint8List.fromList(value))
        .getInt32(0, Endian.little);
  }

  Future<void> writeWinner(
      BluetoothCharacteristic characteristic, String winner) async {
    final bytes = utf8.encode(winner);
    await characteristic.write(bytes);
  }

  Future<int?> readGameState(BluetoothCharacteristic characteristic) async {
    final value = await characteristic.read();
    // if this return value doesnt work, try value[0]
    return ByteData.sublistView(Uint8List.fromList(value))
        .getInt32(0, Endian.little);
  }

  Future<void> writeGameState(
      BluetoothCharacteristic characteristic, int state) async {
    final bytes = ByteData(4)..setInt32(0, state, Endian.little);
    await characteristic.write(bytes.buffer.asUint8List());
    // if this doesn't work try await characteristic.write([value]);
  }

  Future<void> writePlayerCards(
      BluetoothCharacteristic characteristic, String cards) async {
    final bytes = utf8.encode(cards);
    await characteristic.write(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          await Permission.bluetooth.request();
          await Permission.location.request();
          await scanAndConnectToDevices(context);
        },
        child: const Text("Connect to Devices"),
      ),
    );
  }
}
