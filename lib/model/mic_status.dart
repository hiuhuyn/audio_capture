/// Class đại diện cho trạng thái microphone capture
class MicStatus {
  /// Microphone có đang hoạt động không
  final bool isActive;

  /// Tên thiết bị microphone (nếu có)
  final String? deviceName;

  /// Constructor
  const MicStatus({
    required this.isActive,
    this.deviceName,
  });

  /// Tạo từ Map (từ native code)
  factory MicStatus.fromMap(Map<String, dynamic> map) {
    return MicStatus(
      isActive: map['isActive'] as bool? ?? false,
      deviceName: map['deviceName'] as String?,
    );
  }

  /// Chuyển đổi sang Map (để gửi về native code nếu cần)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'isActive': isActive,
    };
    if (deviceName != null) {
      map['deviceName'] = deviceName;
    }
    return map;
  }

  @override
  String toString() {
    return 'MicStatus(isActive: $isActive, deviceName: $deviceName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MicStatus &&
        other.isActive == isActive &&
        other.deviceName == deviceName;
  }

  @override
  int get hashCode => Object.hash(isActive, deviceName);
}
