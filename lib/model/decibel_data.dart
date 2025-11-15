/// Decibel data from audio capture
class DecibelData {
  final double decibel; // -120 to 0 dB
  final double timestamp; // Unix timestamp

  const DecibelData({
    required this.decibel,
    required this.timestamp,
  });

  factory DecibelData.fromMap(Map<String, dynamic> map) {
    return DecibelData(
      decibel: (map['decibel'] as num?)?.toDouble() ?? -120.0,
      timestamp: (map['timestamp'] as num?)?.toDouble() ?? 
          DateTime.now().millisecondsSinceEpoch / 1000.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'decibel': decibel,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() => 'DecibelData(decibel: ${decibel.toStringAsFixed(1)} dB, timestamp: $timestamp)';
}