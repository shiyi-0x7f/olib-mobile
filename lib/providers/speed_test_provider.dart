import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain_provider.dart';

/// Result of a single domain speed test.
class DomainTestResult {
  final String domain;
  /// null = not tested, -1 = failed, >0 = latency in ms
  int? latencyMs;

  DomainTestResult(this.domain, {this.latencyMs});
}

/// State for the speed test provider.
class SpeedTestState {
  final List<DomainTestResult> results;
  final bool testing;
  final int testedCount;

  const SpeedTestState({
    this.results = const [],
    this.testing = false,
    this.testedCount = 0,
  });

  int get onlineCount =>
      results.where((r) => r.latencyMs != null && r.latencyMs! > 0).length;

  SpeedTestState copyWith({
    List<DomainTestResult>? results,
    bool? testing,
    int? testedCount,
  }) {
    return SpeedTestState(
      results: results ?? this.results,
      testing: testing ?? this.testing,
      testedCount: testedCount ?? this.testedCount,
    );
  }
}

class SpeedTestNotifier extends StateNotifier<SpeedTestState> {
  final List<String> _domains;

  /// Max concurrent requests to avoid flooding the network.
  static const int _maxConcurrent = 8;

  SpeedTestNotifier(this._domains) : super(const SpeedTestState()) {
    _initResults();
  }

  void _initResults() {
    state = SpeedTestState(
      results: _domains.map((d) => DomainTestResult(d)).toList(),
    );
  }

  /// Run speed test with bounded concurrency (semaphore pattern).
  /// Safe to call multiple times — ignores if already running.
  Future<void> runTest() async {
    if (state.testing) return;

    // Reset results
    final results = _domains.map((d) => DomainTestResult(d)).toList();
    state = SpeedTestState(results: results, testing: true, testedCount: 0);

    int running = 0;
    int index = 0;
    int tested = 0;
    final completer = Completer<void>();

    void scheduleNext() {
      while (running < _maxConcurrent && index < results.length) {
        final r = results[index++];
        running++;
        _checkDomain(r).whenComplete(() {
          running--;
          tested++;
          state = state.copyWith(
            results: List.from(results),
            testedCount: tested,
          );
          if (index < results.length) {
            scheduleNext();
          } else if (running == 0) {
            completer.complete();
          }
        });
      }
    }

    scheduleNext();
    await completer.future;

    // Sort: successful (ascending latency) first, then failed at bottom.
    results.sort((a, b) {
      final la = a.latencyMs ?? 99999;
      final lb = b.latencyMs ?? 99999;
      final aOk = la > 0 && la < 99999;
      final bOk = lb > 0 && lb < 99999;
      if (aOk && !bOk) return -1;
      if (!aOk && bOk) return 1;
      return la.compareTo(lb);
    });

    state = SpeedTestState(
      results: List.from(results),
      testing: false,
      testedCount: tested,
    );
  }

  Future<void> _checkDomain(DomainTestResult result) async {
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse('https://${result.domain}/eapi/info/languages');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);

      try {
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(
          const Duration(seconds: 8),
        );
        final bodyBytes = await response
            .expand((chunk) => chunk)
            .toList()
            .timeout(const Duration(seconds: 5));
        final body = String.fromCharCodes(bodyBytes);
        sw.stop();

        final isSuccess = body.contains('"success":1') ||
            body.contains('"success": 1') ||
            (response.statusCode >= 200 && response.statusCode < 300);

        result.latencyMs = isSuccess ? sw.elapsedMilliseconds : -1;
      } catch (_) {
        sw.stop();
        result.latencyMs = -1;
      } finally {
        client.close();
      }
    } catch (_) {
      sw.stop();
      result.latencyMs = -1;
    }
  }
}

/// Global speed test state — cached across the app lifecycle.
final speedTestProvider =
    StateNotifierProvider<SpeedTestNotifier, SpeedTestState>((ref) {
  final domains = ref.watch(domainListProvider);
  return SpeedTestNotifier(domains);
});
