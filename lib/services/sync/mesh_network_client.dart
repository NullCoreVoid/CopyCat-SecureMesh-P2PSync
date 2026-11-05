import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import '../../models/security_device_model.dart';

class MeshNetworkClient {
  final String apiKey;
  final int apiPort;
  final String _baseUrl;
  
  IOWebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;

  MeshNetworkClient({required this.apiKey, required this.apiPort})
      : _baseUrl = 'http://127.0.0.1:$apiPort/rest';

  Map<String, String> get _headers => {
    'X-API-Key': apiKey,
    'Content-Type': 'application/json',
  };

  /// Fetches this platform's specific unique cryptographic ID footprint
  Future<String> fetchLocalNodeId() async {
    final response = await http.get(Uri.parse('$_baseUrl/system/status'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['myID'] as String;
    }
    throw Exception('Failed to resolve headless device system configuration details.');
  }

  /// Appends a new scanned peer identifier directly into the engine network ACL configuration map
  Future<void> registerPeerDevice(SecureSyncDevice peer) async {
    final configUrl = Uri.parse('$_baseUrl/config');
    
    // 1. Fetch current runtime engine configuration setup state
    final getResponse = await http.get(configUrl, headers: _headers);
    if (getResponse.statusCode != 200) throw Exception('Unable to access internal config block.');
    
    final Map<String, dynamic> runningConfig = jsonDecode(getResponse.body);
    final List<dynamic> devicesList = runningConfig['devices'] ?? [];

    // Guard statement to avoid duplicate registry cycles
    if (devicesList.any((d) => d['deviceID'] == peer.deviceId)) return;

    // 2. Map and inject configuration parameters dynamically
    devicesList.add({
      'deviceID': peer.deviceId,
      'name': peer.deviceName,
      'addresses': ['tcp://${peer.lastKnownIp}:${peer.lastKnownPort}', 'dynamic'],
      'compression': 'metadata', // Keep pipeline compute footprint light via delta metadata tracking
    });

    runningConfig['devices'] = devicesList;

    // 3. Put mutated setup payload mapping parameters back down to system execution core
    final putResponse = await http.put(
      configUrl,
      headers: _headers,
      body: jsonEncode(runningConfig),
    );

    if (putResponse.statusCode != 200) {
      throw Exception('Failed to finalize pairing mapping profiles down to mesh config.');
    }
  }

  /// Establishes long-lived WebSocket connections to catch peer handshakes reactively
  void initEventStreamingLoop({
    required Function(String deviceId) onPeerConnected,
    required Function(String deviceId) onPeerDisconnected,
    required Function(Map<String, dynamic> syncMetadata) onSyncTransactionCompleted,
  }) {
    final wsUrl = Uri.parse('ws://127.0.0.1:$apiPort/rest/events?events=DeviceConnected,DeviceDisconnected,ItemFinished');
    
    _wsChannel = IOWebSocketChannel.connect(
      wsUrl,
      headers: {'X-API-Key': apiKey},
    );

    _wsSubscription = _wsChannel!.stream.listen(
      (rawEvent) {
        final Map<String, dynamic> eventData = jsonDecode(rawEvent);
        final String type = eventData['type'] ?? '';
        final Map<String, dynamic> data = eventData['data'] ?? {};

        switch (type) {
          case 'DeviceConnected':
            onPeerConnected(data['id'] as String);
            break;
          case 'DeviceDisconnected':
            onPeerDisconnected(data['id'] as String);
            break;
          case 'ItemFinished':
            // Confirms a clipboard text/blob sync delta transfer transaction has finished successfully
            onSyncTransactionCompleted(data);
            break;
        }
      },
      onError: (error) {
        print("💥 Sync WebSocket connection channel tracking encountered error context: $error");
      },
      cancelOnError: false,
    );
  }

  /// Tears down socket threads safely when processing lifecycles change
  void disposeNetworkStreams() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
  }
}
