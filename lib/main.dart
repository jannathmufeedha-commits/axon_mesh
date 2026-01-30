import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:collection';

void main() => runApp(const AxonMasterApp());

class AxonMasterApp extends StatelessWidget {
  const AxonMasterApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: const AxonProEngine(),
  );
}

class AxonProEngine extends StatefulWidget {
  const AxonProEngine({super.key});
  @override
  State<AxonProEngine> createState() => _AxonProEngineState();
}

class _AxonProEngineState extends State<AxonProEngine> {
  final _p2p = FlutterP2pConnection();
  final HashMap<String, Socket> _nodeRegistry = HashMap();
  final Queue<Map<String, dynamic>> _packetQueue = Queue();
  final Set<String> _duplicateFilter = {};
  String _engineStatus = "READY";
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _p2p.initialize();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.nearbyWifiDevices,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
  }

  Future<void> launchEngine() async {
    try {
      bool groupCreated = await _p2p.createGroup();
      if (groupCreated) {
        _initializeServer();
      } else {
        setState(() => _engineStatus = "SCANNING...");
        _p2p.discover();
        _p2p.streamWifiP2PInfo().listen((info) {
          if (info.isConnected && !info.isGroupOwner) {
            _connectToMeshHub(info.groupOwnerAddress);
          }
        });
      }
    } catch (e) { _logError("Boot Fail", e); }
  }

  void _initializeServer() async {
    ServerSocket server = await ServerSocket.bind(InternetAddress.anyIPv4, 8888);
    server.listen((client) => _registerNode(client));
    setState(() => _engineStatus = "ROOT_ACTIVE");
  }

  void _connectToMeshHub(String addr) async {
    try {
      Socket s = await Socket.connect(addr, 8888);
      _registerNode(s);
    } catch (e) { _logError("Connect Fail", e); }
  }

  void _registerNode(Socket socket) {
    String addr = socket.remoteAddress.address;
    _nodeRegistry[addr] = socket;
    socket.listen(
      (data) => _inboundHandler(data, socket),
      onDone: () => _nodeRegistry.remove(addr),
      onError: (e) => _nodeRegistry.remove(addr),
    );
    setState(() => _engineStatus = "NODES: ${_nodeRegistry.length}");
  }

  void _inboundHandler(Uint8List data, Socket sender) {
    try {
      final packet = jsonDecode(utf8.decode(data));
      if (_duplicateFilter.contains(packet['pId'])) return;
      _duplicateFilter.add(packet['pId']);
      _packetQueue.add(packet);
      if (!_isProcessing) _processQueue(sender);
    } catch (e) { }
  }

  Future<void> _processQueue(Socket source) async {
    _isProcessing = true;
    while (_packetQueue.isNotEmpty) {
      final current = _packetQueue.removeFirst();
      final raw = utf8.encode(jsonEncode(current));
      _nodeRegistry.forEach((addr, socket) {
        if (socket != source) socket.add(raw);
      });
    }
    _isProcessing = false;
    setState(() {});
  }

  void _logError(String ctx, dynamic e) => setState(() => _engineStatus = "ERR: $ctx");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("AXON MESH V3"), backgroundColor: Colors.blueGrey[900]),
      body: Column(
        children: [
          Container(padding: const EdgeInsets.all(10), color: Colors.cyanAccent.withOpacity(0.1),
            child: Row(children: [const Icon(Icons.radar, color: Colors.cyanAccent), const SizedBox(width: 10), Text(_engineStatus)])),
          Expanded(child: ListView(children: _nodeRegistry.keys.map((addr) => ListTile(title: Text("Node: $addr"), leading: const Icon(Icons.hub, color: Colors.greenAccent))).toList())),
          Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(onPressed: launchEngine, child: const Text("ACTIVATE MESH")))
        ],
      ),
    );
  }
}
