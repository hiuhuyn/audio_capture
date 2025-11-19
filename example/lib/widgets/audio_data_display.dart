import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class AudioDataDisplay extends StatefulWidget {
  final Stream<Uint8List>? audioStream;
  final String label;
  final int sampleRate;
  final int channels;

  const AudioDataDisplay({
    super.key,
    required this.audioStream,
    required this.label,
    this.sampleRate = 16000,
    this.channels = 1,
  });

  @override
  State<AudioDataDisplay> createState() => _AudioDataDisplayState();
}

class _AudioDataDisplayState extends State<AudioDataDisplay> {
  StreamSubscription<Uint8List>? _subscription;

  // Statistics
  int _totalBytes = 0;
  int _bytesPerSecond = 0;
  double _audioLevel = 0.0; // 0.0 to 1.0
  DateTime? _lastUpdate;
  int _lastBytes = 0;

  // Waveform data (last 100 samples)
  final List<double> _waveformData = List.filled(100, 0.0);
  int _waveformIndex = 0;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    if (widget.audioStream == null) return;

    _subscription = widget.audioStream!.listen(
      (data) {
        if (!mounted) return;

        final now = DateTime.now();

        // Update statistics
        _totalBytes += data.length;

        if (_lastUpdate != null) {
          final elapsed = now.difference(_lastUpdate!).inMilliseconds;
          if (elapsed > 0) {
            final bytesDiff = _totalBytes - _lastBytes;
            _bytesPerSecond = (bytesDiff * 1000 / elapsed).round();
            _lastBytes = _totalBytes;
          }
        } else {
          _lastUpdate = now;
          _lastBytes = _totalBytes;
        }
        _lastUpdate = now;

        // Calculate audio level (RMS)
        _audioLevel = _calculateAudioLevel(data);

        // Update waveform
        _updateWaveform(_audioLevel);

        if (mounted) {
          setState(() {});
        }
      },
      onError: (error) {
        debugPrint('Audio stream error: $error');
      },
    );
  }

  double _calculateAudioLevel(Uint8List data) {
    if (data.isEmpty) return 0.0;

    // Assume 16-bit PCM (2 bytes per sample)
    // Convert bytes to Int16 samples
    final samples = _bytesToSamples(data);
    if (samples.isEmpty) return 0.0;

    // Calculate RMS (Root Mean Square)
    double sum = 0.0;
    for (final sample in samples) {
      final normalized = sample / 32768.0; // Normalize to -1.0 to 1.0
      sum += normalized * normalized;
    }
    final rms = (sum / samples.length);

    // Convert to dB and normalize to 0.0-1.0
    // RMS to dB: 20 * log10(rms)
    // For display, we'll use a simple square root scaling
    return rms.clamp(0.0, 1.0);
  }

  List<int> _bytesToSamples(Uint8List data) {
    // Convert bytes to Int16 samples (little-endian)
    final samples = <int>[];
    for (int i = 0; i < data.length - 1; i += 2) {
      final low = data[i];
      final high = data[i + 1];
      final sample = (high << 8) | low;
      // Convert unsigned to signed
      final signedSample = sample > 32767 ? sample - 65536 : sample;
      samples.add(signedSample);
    }
    return samples;
  }

  void _updateWaveform(double level) {
    _waveformData[_waveformIndex] = level;
    _waveformIndex = (_waveformIndex + 1) % _waveformData.length;
  }

  @override
  void didUpdateWidget(AudioDataDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioStream != widget.audioStream) {
      _subscription?.cancel();
      _totalBytes = 0;
      _bytesPerSecond = 0;
      _audioLevel = 0.0;
      _lastUpdate = null;
      _lastBytes = 0;
      _waveformData.fillRange(0, _waveformData.length, 0.0);
      _waveformIndex = 0;
      _startListening();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audioStream == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.label} Data',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Audio Level Meter
            Row(
              children: [
                const Text('Level: ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _audioLevel,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green,
                              _audioLevel > 0.7 ? Colors.red : Colors.orange,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_audioLevel * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Waveform
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: CustomPaint(
                painter: WaveformPainter(_waveformData),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            // Statistics
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _buildStatItem('Total', _formatBytes(_totalBytes)),
                _buildStatItem('Speed', '${_formatBytes(_bytesPerSecond)}/s'),
                _buildStatItem('Samples', (_totalBytes / 2).toStringAsFixed(0)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> data;

  WaveformPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height / 2 - (data[i] * size.height / 2);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
