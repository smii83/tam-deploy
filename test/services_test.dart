import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tam_app/services/ai_service.dart';
import 'package:tam_app/services/app_provider.dart';
import 'package:tam_app/services/firestore_data_service.dart';
import 'package:tam_app/services/iap_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('IapService.deriveTransactionId', () {
    test('returns trimmed purchaseId when present', () {
      expect(
        IapService.deriveTransactionId('  200000012345  ', '1700000000', 'u1'),
        equals('200000012345'),
      );
    });

    test('falls back to uid + transactionDate when purchaseId is missing', () {
      expect(
        IapService.deriveTransactionId(null, '1700000000', 'user_abc'),
        equals('tx_user_abc_1700000000'),
      );
      expect(
        IapService.deriveTransactionId('   ', ' 1700000001 ', 'user_abc'),
        equals('tx_user_abc_1700000001'),
      );
    });

    test('returns empty string when both purchaseId and transactionDate are empty', () {
      expect(IapService.deriveTransactionId('', '', 'u1'), equals(''));
      expect(IapService.deriveTransactionId(null, null, 'u1'), equals(''));
    });
  });

  group('FirestoreDataService.parseTimestampMillis', () {
    test('parses null, int, double, DateTime, ISO string, and Timestamp', () {
      expect(FirestoreDataService.parseTimestampMillis(null), equals(0));
      expect(FirestoreDataService.parseTimestampMillis(1700000000123), equals(1700000000123));
      expect(FirestoreDataService.parseTimestampMillis(1700000000123.0), equals(1700000000123));

      final dt = DateTime.utc(2026, 5, 1, 12, 0, 0);
      expect(
        FirestoreDataService.parseTimestampMillis(dt),
        equals(dt.millisecondsSinceEpoch),
      );
      expect(
        FirestoreDataService.parseTimestampMillis('2026-05-01T12:00:00Z'),
        equals(dt.millisecondsSinceEpoch),
      );
      expect(
        FirestoreDataService.parseTimestampMillis(Timestamp.fromDate(dt)),
        equals(dt.millisecondsSinceEpoch),
      );
    });
  });

  group('AIService helpers', () {
    test('sniffMime detects JPEG, PNG, and WEBP magic bytes', () {
      expect(
        AIService.sniffMime(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]), ''),
        equals('image/jpeg'),
      );
      expect(
        AIService.sniffMime(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]), ''),
        equals('image/png'),
      );
      expect(
        AIService.sniffMime(Uint8List.fromList([0x52, 0x49, 0x46, 0x46]), ''),
        equals('image/webp'),
      );
      expect(
        AIService.sniffMime(Uint8List.fromList([0x00, 0x01]), 'image/heic'),
        equals('image/heic'),
      );
      expect(
        AIService.sniffMime(Uint8List.fromList([0x00]), 'application/octet-stream'),
        equals('image/jpeg'),
      );
    });

    test('buildChatContentsForTest drops leading model turn and merges consecutive same roles', () {
      final contents = AIService.buildChatContentsForTest(
        [
          {'role': 'assistant', 'content': 'Welcome!'},
          {'role': 'user', 'content': 'Hi'},
          {'role': 'user', 'content': 'Explain quadratic equations'},
          {'role': 'model', 'content': 'Sure, first step:'},
        ],
        'Thanks, next step?',
      );

      expect(contents.length, equals(3));
      expect(contents[0]['role'], equals('user'));
      expect((contents[0]['parts'] as List).length, equals(2));
      expect(contents[1]['role'], equals('model'));
      expect(contents[2]['role'], equals('user'));
    });

    test('extractTextFromResponse filters out thought parts and keeps answer text', () {
      final payload = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'internal reasoning', 'thought': true},
                {'text': 'الجواب النهائي هو 42'},
              ]
            }
          }
        ]
      });
      final res = http.Response.bytes(utf8.encode(payload), 200);
      expect(AIService.extractTextFromResponse(res), equals('الجواب النهائي هو 42'));
    });
  });

  group('AppProvider state & curriculum', () {
    test('default values and setSubscribed notification lifecycle', () {
      final provider = AppProvider();
      expect(provider.language, equals('ar'));
      expect(provider.selectedCountry, equals('kw'));
      expect(provider.isSubscribed, isFalse);

      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.setSubscribed(true);
      provider.setSubscribed(true); // redundant update should not notify
      expect(provider.isSubscribed, isTrue);
      expect(notifications, equals(1));

      provider.setSubscribed(false);
      expect(provider.isSubscribed, isFalse);
      expect(notifications, equals(2));
    });

    test('setCountry updates country and curriculum across kw, sa, ae', () async {
      final provider = AppProvider();
      await provider.setCountry('sa');
      expect(provider.selectedCountry, equals('sa'));

      await provider.setLanguage('en');
      expect(provider.language, equals('en'));
      expect(provider.isAr, isFalse);

      expect(AppProvider.getSubjects(12, 'scientific', 'kw'), isNotEmpty);
      expect(AppProvider.getSubjects(12, 'scientific', 'sa'), isNotEmpty);
      expect(AppProvider.getSubjects(12, 'scientific', 'ae'), isNotEmpty);
    });
  });
}
