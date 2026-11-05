import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class HeadlessEngineService {
  Process? _engineProcess;
  String? _secureApiKey;
  int? _runtimePort;

  String? get apiKey => _secureApiKey;
  int? get port => _runtimePort;

  /// Main bootstrapper called during app startup sequences
  Future<void> bootEngine() async {
    if (_engineProcess != null) return; // Engine is already running

    final Directory appDocDir = await getApplicationSupportDirectory();
    final String binaryName = Platform.isWindows ? 'syncthing_core.exe' : 'syncthing_core.bin';
    final File targetFile = File('${appDocDir.path}/$binaryName');

    // 1. Extract the asset file to the platform-specific sandboxed directory
    final String assetSource = Platform.isWindows
        ? 'assets/engine/windows_amd64/syncthing_core.exe'
        : 'assets/engine/android_arm64/syncthing_core';

    final ByteData data = await rootBundle.load(assetSource);
    await targetFile.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));

    // Ensure execution permissions on Unix-like kernels (Android)
    if (!Platform.isWindows) {
      await Process.run('chmod', ['755', targetFile.path]);
    }

    // 2. Generate security tokens and look for open local routing interfaces
    _secureApiKey = _generateCryptographicToken(32);
    _runtimePort = await _findAvailableNetworkPort(8384);

    // 3. Launch process with explicit flags to strip resource-heavy UI layers
    _engineProcess = await Process.start(
      targetFile.path,
      [
        '--no-browser',
        '--no-restart',
        '--gui-address=127.0.0.1:$_runtimePort',
        '--home=${appDocDir.path}/mesh_config',
      ],
      environment: {
        'SYNCTHING_API_KEY': _secureApiKey!,
      },
    );

    // Pipe process threads out to project debugging streams for open-source verification
    _engineProcess!.stdout.transform(utf8.decoder).listen((log) => print("📋 MESH ENGINE: $log"));
    _engineProcess!.stderr.transform(utf8.decoder).listen((err) => print("⚠️ MESH ERROR: $err"));
  }

  Future<void> terminateEngine() async {
    _engineProcess?.kill();
    _engineProcess = null;
    print("🔌 Headless engine safely terminated.");
  }

  String _generateCryptographicToken(int length) {
    final Random random = Random.secure();
    final List<int> values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  Future<int> _findAvailableNetworkPort(int startingPort) async {
    int targetPort = startingPort;
    while (targetPort < startingPort + 100) {
      try {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, targetPort);
        await socket.close();
        return targetPort;
      } catch (_) {
        targetPort++;
      }
    }
    return startingPort;
  }
}
