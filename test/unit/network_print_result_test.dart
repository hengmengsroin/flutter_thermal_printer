import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_thermal_printer/network/network_print_result.dart';

void main() {
  group('NetworkPrintResult', () {
    group('static constants', () {
      test('success has value 1', () {
        expect(NetworkPrintResult.success.value, 1);
      });

      test('timeout has value 2', () {
        expect(NetworkPrintResult.timeout.value, 2);
      });

      test('printerConnected has value 3', () {
        expect(NetworkPrintResult.printerConnected.value, 3);
      });

      test('ticketEmpty has value 4', () {
        expect(NetworkPrintResult.ticketEmpty.value, 4);
      });

      test('printInProgress has value 5', () {
        expect(NetworkPrintResult.printInProgress.value, 5);
      });

      test('scanInProgress has value 6', () {
        expect(NetworkPrintResult.scanInProgress.value, 6);
      });
    });

    group('msg getter', () {
      test('success returns Success', () {
        expect(NetworkPrintResult.success.msg, 'Success');
      });

      test('timeout returns connection timeout message', () {
        expect(
          NetworkPrintResult.timeout.msg,
          'Error. Printer connection timeout',
        );
      });

      test('printerConnected returns not connected message', () {
        expect(
          NetworkPrintResult.printerConnected.msg,
          'Error. Printer not connected',
        );
      });

      test('ticketEmpty returns empty ticket message', () {
        expect(NetworkPrintResult.ticketEmpty.msg, 'Error. Ticket is empty');
      });

      test('printInProgress returns print in progress message', () {
        expect(
          NetworkPrintResult.printInProgress.msg,
          'Error. Another print in progress',
        );
      });

      test('scanInProgress returns scan in progress message', () {
        expect(
          NetworkPrintResult.scanInProgress.msg,
          'Error. Printer scanning in progress',
        );
      });
    });

    group('equality', () {
      test('same constant instances are equal', () {
        expect(NetworkPrintResult.success, NetworkPrintResult.success);
        expect(NetworkPrintResult.timeout, NetworkPrintResult.timeout);
      });

      test('different constants are not equal', () {
        expect(
          NetworkPrintResult.success == NetworkPrintResult.timeout,
          false,
        );
      });
    });

    group('value comparison', () {
      test('can compare by value', () {
        expect(
          NetworkPrintResult.success.value == 1,
          true,
        );
        expect(
          NetworkPrintResult.timeout.value == 2,
          true,
        );
      });
    });
  });
}
