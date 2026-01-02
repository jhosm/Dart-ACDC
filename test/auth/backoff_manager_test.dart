import 'package:dart_acdc/src/auth/backoff_manager.dart';
import 'package:test/test.dart';

void main() {
  group('BackoffManager', () {
    late BackoffManager manager;

    setUp(() {
      manager = BackoffManager();
    });

    group('initial state', () {
      test('starts with zero backoff', () {
        expect(manager.currentBackoffSeconds, equals(0));
      });

      test('shouldWait returns false initially', () {
        expect(manager.shouldWait(), isFalse);
      });

      test('getWaitDuration returns zero initially', () {
        expect(manager.getWaitDuration(), equals(Duration.zero));
      });
    });

    group('waitIfNeeded', () {
      test('completes immediately when no backoff is set', () async {
        final stopwatch = Stopwatch()..start();

        await manager.waitIfNeeded();

        stopwatch.stop();
        // Should complete almost instantly (< 100ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('waits for backoff duration when backoff is set', () async {
        // First attempt - records timestamp but doesn't wait
        await manager.waitIfNeeded();

        manager.increment(); // Sets 1 second backoff
        expect(manager.currentBackoffSeconds, equals(1));

        final stopwatch = Stopwatch()..start();
        await manager.waitIfNeeded(); // Should wait 1 second
        stopwatch.stop();

        // Should wait approximately 1 second (allow 100ms tolerance)
        expect(stopwatch.elapsedMilliseconds, greaterThan(900));
        expect(stopwatch.elapsedMilliseconds, lessThan(1200));
      });

      test('records last attempt timestamp', () async {
        await manager.waitIfNeeded();

        // After waiting, should not need to wait again immediately
        // (since we just recorded the attempt)
        expect(manager.shouldWait(), isFalse);
      });

      test('waits partial duration if some time has passed', () async {
        manager.increment(); // 1 second backoff

        // First wait
        await manager.waitIfNeeded();

        // Increment again (2 seconds backoff)
        manager.increment();

        // Wait a bit
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Should only wait remaining time (~1.5 seconds)
        final stopwatch = Stopwatch()..start();
        await manager.waitIfNeeded();
        stopwatch.stop();

        // Should wait less than full 2 seconds
        expect(stopwatch.elapsedMilliseconds, lessThan(1700));
        expect(stopwatch.elapsedMilliseconds, greaterThan(1300));
      });
    });

    group('reset', () {
      test('clears backoff to zero', () {
        manager.increment();
        expect(manager.currentBackoffSeconds, equals(1));

        manager.reset();

        expect(manager.currentBackoffSeconds, equals(0));
      });

      test('allows immediate retry after reset', () async {
        manager.increment();
        await manager.waitIfNeeded(); // Records an attempt

        expect(manager.shouldWait(), isFalse); // Just waited, no more needed

        manager.reset();

        expect(manager.shouldWait(), isFalse);
        expect(manager.getWaitDuration(), equals(Duration.zero));
      });
    });

    group('increment', () {
      test('sets initial backoff to 1 second', () {
        manager.increment();

        expect(manager.currentBackoffSeconds, equals(1));
      });

      test('doubles backoff on subsequent increments', () {
        manager
          ..increment() // 1
          ..increment() // 2
          ..increment() // 4
          ..increment(); // 8

        expect(manager.currentBackoffSeconds, equals(8));

        manager.increment(); // 16
        expect(manager.currentBackoffSeconds, equals(16));
      });

      test('respects default max of 30 seconds', () {
        // Increment many times to exceed max
        for (var i = 0; i < 10; i++) {
          manager.increment();
        }

        expect(manager.currentBackoffSeconds, equals(30));
      });

      test('respects custom max seconds', () {
        manager
          ..increment(maxSeconds: 10) // 1
          ..increment(maxSeconds: 10) // 2
          ..increment(maxSeconds: 10) // 4
          ..increment(maxSeconds: 10) // 8
          ..increment(maxSeconds: 10); // Should clamp to 10

        expect(manager.currentBackoffSeconds, equals(10));
      });

      test('exponential progression example', () {
        final progression = <int>[];

        for (var i = 0; i < 6; i++) {
          manager.increment();
          progression.add(manager.currentBackoffSeconds);
        }

        expect(progression, equals([1, 2, 4, 8, 16, 30]));
      });
    });

    group('shouldWait', () {
      test('returns false when backoff is zero', () {
        expect(manager.shouldWait(), isFalse);
      });

      test('returns false when no last attempt recorded', () {
        manager.increment();

        // Haven't called waitIfNeeded yet, so no last attempt
        // No previous attempt means no backoff needed yet
        expect(manager.shouldWait(), isFalse);
      });

      test('returns true when backoff period has not elapsed', () async {
        manager.increment(); // 1 second backoff
        await manager.waitIfNeeded(); // Records last attempt

        // Immediately after, should still need to wait
        manager.increment(); // 2 seconds backoff

        expect(manager.shouldWait(), isTrue);
      });

      test('returns false after backoff period elapses', () async {
        manager.increment(); // 1 second backoff
        await manager.waitIfNeeded();

        manager.increment(); // 2 seconds backoff

        // Wait for backoff to elapse
        await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 100));

        expect(manager.shouldWait(), isFalse);
      });
    });

    group('getWaitDuration', () {
      test('returns zero when no backoff needed', () {
        expect(manager.getWaitDuration(), equals(Duration.zero));
      });

      test('returns zero when no last attempt', () {
        manager.increment(); // 1 second

        final duration = manager.getWaitDuration();
        // No last attempt means no backoff needed yet
        expect(duration, equals(Duration.zero));
      });

      test('returns remaining duration after partial wait', () async {
        manager.increment(); // 1 second backoff
        await manager.waitIfNeeded();

        manager.increment(); // 2 seconds backoff

        // Wait 500ms
        await Future<void>.delayed(const Duration(milliseconds: 500));

        final remainingDuration = manager.getWaitDuration();

        // Should be approximately 1.5 seconds remaining
        expect(remainingDuration.inMilliseconds, greaterThan(1300));
        expect(remainingDuration.inMilliseconds, lessThan(1700));
      });

      test('returns zero after backoff elapses', () async {
        manager.increment();
        await manager.waitIfNeeded();

        // Wait for backoff to elapse
        await Future<void>.delayed(const Duration(milliseconds: 1100));

        expect(manager.getWaitDuration(), equals(Duration.zero));
      });
    });

    group('integration scenarios', () {
      test('typical retry scenario with backoff', () async {
        // First attempt - no backoff
        await manager.waitIfNeeded();
        expect(manager.currentBackoffSeconds, equals(0));

        // First failure - set backoff
        manager.increment();
        expect(manager.currentBackoffSeconds, equals(1));

        // Second attempt - wait 1 second
        final stopwatch1 = Stopwatch()..start();
        await manager.waitIfNeeded();
        stopwatch1.stop();
        expect(stopwatch1.elapsedMilliseconds, greaterThan(900));

        // Second failure - increase backoff
        manager.increment();
        expect(manager.currentBackoffSeconds, equals(2));

        // Third attempt - wait 2 seconds
        final stopwatch2 = Stopwatch()..start();
        await manager.waitIfNeeded();
        stopwatch2.stop();
        expect(stopwatch2.elapsedMilliseconds, greaterThan(1900));

        // Success - reset
        manager.reset();
        expect(manager.currentBackoffSeconds, equals(0));

        // Next attempt - no wait
        final stopwatch3 = Stopwatch()..start();
        await manager.waitIfNeeded();
        stopwatch3.stop();
        expect(stopwatch3.elapsedMilliseconds, lessThan(100));
      });

      test('max backoff reached scenario', () {
        // Simulate many consecutive failures
        for (var i = 0; i < 10; i++) {
          manager.increment(maxSeconds: 16);
        }

        expect(manager.currentBackoffSeconds, equals(16));

        // Reset and verify clean state
        manager.reset();
        expect(manager.currentBackoffSeconds, equals(0));
      });
    });
  });
}
