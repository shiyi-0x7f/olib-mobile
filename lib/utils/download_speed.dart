/// 速度读数：`350 KB/s`、`1.2 MB/s`（1024 进制，与文件大小显示一致）
String formatSpeed(int bytesPerSecond) {
  const kb = 1024, mb = 1024 * 1024;
  if (bytesPerSecond >= mb) {
    return '${(bytesPerSecond / mb).toStringAsFixed(1)} MB/s';
  }
  if (bytesPerSecond >= kb) return '${(bytesPerSecond / kb).round()} KB/s';
  return '$bytesPerSecond B/s';
}

/// 下载速度计量：按最近 [window] 内的字节增量求平均速度，
/// 并最多每 [interval] 刷新一次读数，避免进度回调过密时数字乱跳。
class DownloadSpeedMeter {
  final Duration window;
  final Duration interval;
  final DateTime Function() _now;

  final List<(DateTime, int)> _samples = [];
  DateTime? _lastEmit;
  int _speed = 0;

  DownloadSpeedMeter({
    this.window = const Duration(seconds: 3),
    this.interval = const Duration(milliseconds: 500),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// 记录当前已接收字节数，返回当前速度（字节/秒）。
  int sample(int receivedBytes) {
    final now = _now();
    _samples.add((now, receivedBytes));
    final cutoff = now.subtract(window);
    // 保留窗口内样本，外加窗口前最后一个作为基准点
    while (_samples.length > 2 && _samples[1].$1.isBefore(cutoff)) {
      _samples.removeAt(0);
    }

    final last = _lastEmit;
    if (last != null && now.difference(last) < interval) return _speed;

    final (startAt, startBytes) = _samples.first;
    final elapsedMs = now.difference(startAt).inMilliseconds;
    // 样本跨度不足一个刷新间隔时不出读数：开头几个分块间隔仅几毫秒，
    // 直接相除会算出虚高的瞬时速度
    if (elapsedMs < interval.inMilliseconds) return _speed;
    _speed = ((receivedBytes - startBytes) * 1000 / elapsedMs).round();
    if (_speed < 0) _speed = 0;
    _lastEmit = now;
    return _speed;
  }
}
