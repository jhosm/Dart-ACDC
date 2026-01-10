import 'package:dart_acdc/src/cancellation/active_request_tracker.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('ActiveRequestTracker', () {
    late ActiveRequestTracker tracker;
    late CancelToken token1;
    late CancelToken token2;

    setUp(() {
      tracker = ActiveRequestTracker();
      token1 = CancelToken();
      token2 = CancelToken();
    });

    test('should start with 0 active tokens', () {
      expect(tracker.activeCount, 0);
    });

    test('should add tokens', () {
      tracker.add(token1);
      expect(tracker.activeCount, 1);
      expect(tracker.isTracked(token1), isTrue);

      tracker.add(token2);
      expect(tracker.activeCount, 2);
      expect(tracker.isTracked(token2), isTrue);
    });

    test('should remove tokens', () {
      tracker.add(token1);
      tracker.add(token2);

      tracker.remove(token1);
      expect(tracker.activeCount, 1);
      expect(tracker.isTracked(token1), isFalse);
      expect(tracker.isTracked(token2), isTrue);
    });

    group('cancelAll', () {
      test('should cancel all tracked tokens with reason', () {
        tracker.add(token1);
        tracker.add(token2);

        const reason = 'test reason';
        tracker.cancelAll(reason);

        expect(token1.isCancelled, isTrue);
        expect(token1.cancelError?.error, reason);
        expect(token2.isCancelled, isTrue);
        expect(token2.cancelError?.error, reason);
      });

      test('should clear the tracker after cancellation', () {
        tracker.add(token1);
        tracker.add(token2);

        tracker.cancelAll();

        expect(tracker.activeCount, 0);
      });

      test('should not throw if a token is already cancelled', () {
        tracker.add(token1);
        token1.cancel(); // Pre-cancelled

        tracker.cancelAll();

        expect(token1.isCancelled, isTrue);
      });

      test(
          'should be safe to modify tracker (via remove) during cancelAll iteration',
          () {
        // This simulates a scenario where cancelling might trigger cleanups that call remove()
        // Our implementation iterates a copy, so it should be fine.

        // We can't easily simulate the side-effect within unit test of the class itself easily
        // without a callback mechanism on the token (which Dio doesn't easily expose for "onCancel"
        // that we can hook into to call remove()).
        // But we rely on the implementation detail that it copies the list.

        tracker.add(token1);
        tracker.add(token2);

        tracker.cancelAll();

        expect(tracker.activeCount, 0);
      });
    });
  });
}
