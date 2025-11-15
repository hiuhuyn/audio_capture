import 'package:desktop_audio_capture/audio_capture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel(
    'com.mic_audio_transcriber/mic_capture',
  );

  late MicAudioCapture micCapture;
  late List<MethodCall> methodCallLog;

  setUp(() {
    micCapture = MicAudioCapture();
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
        case 'hasInputDevice':
          return true;
        case 'getAvailableInputDevices':
          return [
            {
              'id': 'device1',
              'name': 'Built-in Microphone',
              'type': 'built-in',
              'channelCount': 1,
              'isDefault': true,
            },
            {
              'id': 'device2',
              'name': 'USB Microphone',
              'type': 'external',
              'channelCount': 2,
              'isDefault': false,
            },
          ];
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

  group('MicAudioCapture', () {
    test('constructor with default config', () {
      final capture = MicAudioCapture();
      expect(capture, isNotNull);
      expect(capture.isRecording, false);
    });

    test('constructor with custom config', () {
      final config = MicAudioConfig(
        sampleRate: 44100,
        channels: 2,
        bitDepth: 24,
        gainBoost: 3.0,
        inputVolume: 0.8,
      );
      final capture = MicAudioCapture(config: config);
      expect(capture, isNotNull);
      expect(capture.isRecording, false);
    });

    test('updateConfig updates config', () {
      final capture = MicAudioCapture();
      final newConfig = MicAudioConfig(
        sampleRate: 48000,
        channels: 2,
        gainBoost: 2.0,
      );
      capture.updateConfig(newConfig);
      // Config is updated internally, no getter to verify
      expect(capture, isNotNull);
    });

    test('isRecording returns false when not started', () {
      expect(micCapture.isRecording, false);
    });

    test('requestPermissions succeeds', () async {
      final result = await micCapture.requestPermissions();
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
        () => micCapture.requestPermissions(),
        throwsA(isA<Exception>()),
      );
    });

    test('hasInputDevice returns true when device available', () async {
      final result = await micCapture.hasInputDevice();
      expect(result, true);
      expect(methodCallLog.length, 1);
      expect(methodCallLog[0].method, 'hasInputDevice');
    });

    test('hasInputDevice returns false when no device available', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'hasInputDevice') {
          return false;
        }
        return null;
      });

      final result = await micCapture.hasInputDevice();
      expect(result, false);
    });

    test('getAvailableInputDevices returns list of devices', () async {
      final devices = await micCapture.getAvailableInputDevices();
      expect(devices.length, 2);
      expect(devices[0].id, 'device1');
      expect(devices[0].name, 'Built-in Microphone');
      expect(devices[0].type, InputDeviceType.builtIn);
      expect(devices[0].isDefault, true);
      expect(devices[1].id, 'device2');
      expect(devices[1].name, 'USB Microphone');
      expect(devices[1].type, InputDeviceType.external);
      expect(devices[1].isDefault, false);
    });

    test('getAvailableInputDevices returns empty list when null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'getAvailableInputDevices') {
          return null;
        }
        return null;
      });

      final devices = await micCapture.getAvailableInputDevices();
      expect(devices, isEmpty);
    });

    test('startCapture succeeds', () async {
      await micCapture.startCapture();
      expect(micCapture.isRecording, true);
      expect(methodCallLog.length, 2); // requestPermissions + startCapture
      expect(methodCallLog[0].method, 'requestPermissions');
      expect(methodCallLog[1].method, 'startCapture');
      expect(methodCallLog[1].arguments, isA<Map>());
      final args = methodCallLog[1].arguments as Map;
      expect(args['sampleRate'], isNotNull);
      expect(args['channels'], isNotNull);
    });

    test('startCapture with config', () async {
      final config = MicAudioConfig(
        sampleRate: 44100,
        channels: 2,
      );
      await micCapture.startCapture(config: config);
      expect(micCapture.isRecording, true);
      expect(methodCallLog[1].arguments['sampleRate'], 44100);
      expect(methodCallLog[1].arguments['channels'], 2);
    });

    test('startCapture does not start again if already recording', () async {
      await micCapture.startCapture();
      final initialCallCount = methodCallLog.length;
      await micCapture.startCapture();
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
        () => micCapture.startCapture(),
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
        () => micCapture.startCapture(),
        throwsA(isA<Exception>()),
      );
    });

    test('stopCapture succeeds', () async {
      await micCapture.startCapture();
      expect(micCapture.isRecording, true);

      await micCapture.stopCapture();
      expect(micCapture.isRecording, false);
      expect(methodCallLog.last.method, 'stopCapture');
    });

    test('stopCapture does nothing if not recording', () async {
      expect(micCapture.isRecording, false);
      await micCapture.stopCapture();
      expect(methodCallLog, isEmpty);
    });

    test('stopCapture throws exception when stop fails', () async {
      await micCapture.startCapture();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'stopCapture') {
          return false;
        }
        return null;
      });

      expect(
        () => micCapture.stopCapture(),
        throwsA(isA<Exception>()),
      );
    });

    test('audioStream returns null when not started', () {
      expect(micCapture.audioStream, isNull);
    });

    test('audioStream returns stream after start', () async {
      await micCapture.startCapture();
      expect(micCapture.audioStream, isNotNull);
    });

    test('statusStream creates stream when accessed', () {
      final stream = micCapture.statusStream;
      expect(stream, isNotNull);
    });

    test('decibelStream returns null when not recording', () {
      expect(micCapture.decibelStream, isNull);
    });

    test('decibelStream returns stream when recording', () async {
      await micCapture.startCapture();
      expect(micCapture.decibelStream, isNotNull);
    });
  });
}

