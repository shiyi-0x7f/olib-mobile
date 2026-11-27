import 'package:flutter_test/flutter_test.dart';
import 'package:olib_mobile/utils/download_speed.dart';

void main() {
  group('DownloadSpeedMeter', () {
    late DateTime now;
    late DownloadSpeedMeter meter;

    setUp(() {
      now = DateTime(2026);
      meter = DownloadSpeedMeter(now: () => now);
    });

    void advance(int ms) => now = now.add(Duration(milliseconds: ms));

    test('computes average speed over elapsed time', () {
      expect(meter.sample(0), 0);
      advance(1000);
      expect(meter.sample(1024 * 1024), 1024 * 1024);
    });

    test('no spike from first chunks a few ms apart', () {
      meter.sample(0);
      advance(2);
      expect(meter.sample(64 * 1024), 0);
      advance(600);
      expect(meter.sample(128 * 1024), lessThan(300 * 1024));
    });

    test('throttles readings within interval', () {
      meter.sample(0);
      advance(1000);
      final first = meter.sample(1000);
      advance(100);
      expect(meter.sample(100000), first);
    });

    test('only uses samples inside the window', () {
      meter.sample(0);
      // 前 5 秒慢速：每秒 100 B
      for (var i = 1; i <= 5; i++) {
        advance(1000);
        meter.sample(i * 100);
      }
      // 之后 3 秒快速：每秒 10000 B
      var bytes = 500;
      for (var i = 0; i < 3; i++) {
        advance(1000);
        bytes += 10000;
        meter.sample(bytes);
      }
      advance(1000);
      bytes += 10000;
      final speed = meter.sample(bytes);
      expect(speed, greaterThan(7000));
    });

    test('never reports negative speed', () {
      meter.sample(5000);
      advance(1000);
      expect(meter.sample(0), 0);
    });
  });

  test('formatSpeed', () {
    expect(formatSpeed(500), '500 B/s');
    expect(formatSpeed(350 * 1024), '350 KB/s');
    expect(formatSpeed((1.25 * 1024 * 1024).round()), '1.3 MB/s');
  });
}
