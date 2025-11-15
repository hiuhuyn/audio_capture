import 'package:desktop_audio_capture/audio_capture.dart';
import 'package:desktop_audio_capture/system/system_audio_capture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel(
    'com.system_audio_transcriber/audio_capture',
  );

  late SystemAudioCapture systemCapture;
  late List<MethodCall> methodCallLog;

  setUp(() {
    systemCapture = SystemAudioCapture();
    methodCallLog = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
      methodCallLog.add(methodCall);
      switch (methodCall.method) {
        case 'requestPermissions':
          return true;
        case 'startCapture':
          return true;
        case 'stopCapture':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    methodCallLog.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('SystemAudioCapture', () {
    test('constructor with default config', () {
      final capture = SystemAudioCapture();
      expect(capture, isNotNull);
      expect(capture.isRecording, false);
    });

    test('constructor with custom config', () {
      final config = SystemAudioConfig(
        sampleRate: 44100,
        channels: 2,
      );
      final capture = SystemAudioCapture(config: config);
      expect(capture, isNotNull);
      expect(capture.isRecording, false);
    });

    test('updateConfig updates config', () {
      final capture = SystemAudioCapture();
      final newConfig = SystemAudioConfig(
        sampleRate: 48000,
        channels: 2,
      );
      capture.updateConfig(newConfig);
      // Config is updated internally, no getter to verify
      expect(capture, isNotNull);
    });

    test('isRecording returns false when not started', () {
      expect(systemCapture.isRecording, false);
    });

    test('requestPermissions succeeds', () async {
      final result = await systemCapture.requestPermissions();
      expect(result, true);
      expect(methodCallLog.length, 1);
      expect(methodCallLog[0].method, 'requestPermissions');
    });

    test('requestPermissions fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'requestPermissions') {
          return false;
        }
        return null;
      });

      expect(
        () => systemCapture.requestPermissions(),
        throwsA(isA<Exception>()),
      );
    });

    test('startCapture succeeds', () async {
      await systemCapture.startCapture();
      expect(systemCapture.isRecording, true);
      expect(methodCallLog.length, 2); // requestPermissions + startCapture
      expect(methodCallLog[0].method, 'requestPermissions');
      expect(methodCallLog[1].method, 'startCapture');
      expect(methodCallLog[1].arguments, isA<Map>());
      final args = methodCallLog[1].arguments as Map;
      expect(args['sampleRate'], isNotNull);
      expect(args['channels'], isNotNull);
    });

    test('startCapture with config', () async {
      final config = SystemAudioConfig(
        sampleRate: 44100,
        channels: 2,
      );
      await systemCapture.startCapture(config: config);
      expect(systemCapture.isRecording, true);
      expect(methodCallLog[1].arguments['sampleRate'], 44100);
      expect(methodCallLog[1].arguments['channels'], 2);
    });

    test('startCapture does not start again if already recording', () async {
      await systemCapture.startCapture();
      final initialCallCount = methodCallLog.length;
      await systemCapture.startCapture();
      // No additional method calls
      expect(methodCallLog.length, initialCallCount);
    });

    test('startCapture throws exception when permission denied', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'requestPermissions') {
          return false;
        }
        return null;
      });

      expect(
        () => systemCapture.startCapture(),
        throwsA(isA<Exception>()),
      );
    });

    test('startCapture throws exception when start fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'requestPermissions') {
          return true;
        }
        if (methodCall.method == 'startCapture') {
          return false;
        }
        return null;
      });

      expect(
        () => systemCapture.startCapture(),
        throwsA(isA<Exception>()),
      );
    });

    test('stopCapture succeeds', () async {
      await systemCapture.startCapture();
      expect(systemCapture.isRecording, true);

      await systemCapture.stopCapture();
      expect(systemCapture.isRecording, false);
      expect(methodCallLog.last.method, 'stopCapture');
    });

    test('stopCapture does nothing if not recording', () async {
      expect(systemCapture.isRecording, false);
      await systemCapture.stopCapture();
      expect(methodCallLog, isEmpty);
    });

    test('stopCapture throws exception when stop fails', () async {
      await systemCapture.startCapture();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'stopCapture') {
          return false;
        }
        return null;
      });

      expect(
        () => systemCapture.stopCapture(),
        throwsA(isA<Exception>()),
      );
    });

    test('audioStream returns null when not started', () {
      expect(systemCapture.audioStream, isNull);
    });

    test('audioStream returns stream after start', () async {
      await systemCapture.startCapture();
      expect(systemCapture.audioStream, isNotNull);
    });

    test('statusStream creates stream when accessed', () {
      final stream = systemCapture.statusStream;
      expect(stream, isNotNull);
    });

    test('decibelStream returns null when not recording', () {
      expect(systemCapture.decibelStream, isNull);
    });

    test('decibelStream returns stream when recording', () async {
      await systemCapture.startCapture();
      expect(systemCapture.decibelStream, isNotNull);
    });
  });
}

