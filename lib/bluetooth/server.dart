// Dart Imports
import 'dart:async';
import 'dart:convert' show utf8;

// Package Imports
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// Constants
const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String TARGET_DEVICE_NAME = "Poker";

class Server extends StatefulWidget {
  const Server({super.key});

  @override
  State<Server> createState() => _ServerState();
}

class _ServerState extends State<Server> {
  final _bleDeviceController = TextEditingController()
    ..text = TARGET_DEVICE_NAME;
  final _dataController = TextEditingController();

  FlutterBluePlus flutterBlue = FlutterBluePlus();
  late StreamSubscription<ScanResult> scanSubscription;
  late BluetoothDevice targetDevice;
  late BluetoothCharacteristic targetCharacteristic;

  // connecting multiple bluetooth devices
  // key = device ID
  // value = Bluetooth Device
  Map<String, BluetoothDevice> connectedDevices = {};

  String bleStatus = "No Connection";
  String bleLastRead = "N/A";
  bool targetDeviceFound = false;
  bool isConnectedToTarget = false;
  String btnConnectionText = "Connect";

  _startScan() {
    setState(() => bleStatus = "Scanning available BLE devices...");

    // Start scan with timeout using the `startScan` method which returns a `Future`
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10)).then((_) {
      // This will be executed after the scan is completed
      setState(() => bleStatus = "Scan completed");
    });

    // Listen to the scan results stream, which emits a List<ScanResult> each time
    scanSubscription =
        FlutterBluePlus.scanResults.listen((List<ScanResult> scanResults) {
      for (var scanResult in scanResults) {
        if (scanResult.device.platformName == _bleDeviceController.text) {
          setState(() {
            targetDevice = scanResult.device;
            bleStatus = "Found ${targetDevice.platformName}";
            targetDeviceFound = true;
            btnConnectionText = "Connect";
          });

          _stopScan();
          scanSubscription.cancel();
          break;
        }
      }
    }) as StreamSubscription<ScanResult>;
  }

  _stopScan() {
    FlutterBluePlus.stopScan();
    setState(() => bleStatus = "${_bleDeviceController.text} not found");
  }

  _checkPermissions() async {
    if (await Permission.bluetoothScan.request().isGranted) {
      print("BLE Scan Permission Granted");
    } else {
      print("BLE Scan Permission NOT Granted");
    }

    if (await Permission.bluetoothConnect.request().isGranted) {
      print("BLE Connect Permission Granted");
    } else {
      print("BLE Connect Permission NOT Granted");
    }
  }

  _connectToDevice() async {
    setState(() => bleStatus = "Connecting to ${targetDevice.platformName}");
    await targetDevice.connect();
    setState(() {
      bleStatus = "Connected to ${targetDevice.platformName}";
      isConnectedToTarget = true;
      btnConnectionText = "Disconnect";
    });
    _discoverServices();
  }

  _disconnectFromDevice() {
    targetDevice.disconnect();
    setState(() {
      bleStatus = "Disconnected";
      isConnectedToTarget = false;
      btnConnectionText = "Connect";
      targetDeviceFound = false;
    });
  }

  _discoverServices() async {
    List<BluetoothService> services = await targetDevice.discoverServices();
    for (var service in services) {
      if (service.uuid.toString() == SERVICE_UUID) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == CHARACTERISTIC_UUID) {
            targetCharacteristic = characteristic;
          }
        }
      }
    }
  }

  _writeTextFieldData() async {
    await _writeData(_dataController.text);
  }

  _writeData(String data) async {
    List<int> bytes = utf8.encode(data);
    await targetCharacteristic.write(bytes);
  }

  _readData() async {
    List<int> bytes = await targetCharacteristic.read();
    setState(() => bleLastRead = utf8.decode(bytes));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "BLE Connection Actions",
                style: TextStyle(fontSize: 28),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'BLE Device Name'),
                controller: _bleDeviceController,
              ),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _checkPermissions(),
                    child: const Text('Ensure Permissions'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _startScan(),
                    child: const Text('Scan'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: !targetDeviceFound
                        ? null
                        : () {
                            if (isConnectedToTarget) {
                              _disconnectFromDevice();
                            } else {
                              _connectToDevice();
                            }
                          },
                    child: Text(btnConnectionText),
                  ),
                ],
              ),
              Text(
                "BLE Status: $bleStatus",
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 40),
              const Text(
                "BLE Read/Write Actions",
                style: TextStyle(fontSize: 28),
              ),
              ElevatedButton(
                onPressed: () => _readData(),
                child: const Text('Read from ESP32'),
              ),
              Text(
                "Last Read: $bleLastRead",
                style: const TextStyle(fontSize: 20),
              ),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _writeTextFieldData(),
                    child: const Text('Write to ESP32'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Data'),
                      controller: _dataController,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
