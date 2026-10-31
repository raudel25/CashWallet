import 'package:cash_wallet/app.dart';
import 'package:cash_wallet/data/crypto_entry_repository.dart';
import 'package:cash_wallet/data/crypto_wallet_repository.dart';
import 'package:cash_wallet/models/cash_entry.dart';
import 'package:cash_wallet/models/crypto_entry.dart';
import 'package:cash_wallet/models/crypto_network.dart';
import 'package:cash_wallet/models/crypto_wallet.dart';
import 'dart:convert';

import 'package:cash_wallet/services/chain_balance_service.dart';
import 'package:cash_wallet/services/export_service.dart';
import 'package:cash_wallet/ui/widgets/crypto_movement_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CryptoNetwork', () {
    test('validates addresses per family', () {
      final bep20 = CryptoNetworks.byId('bep20')!;
      final trc20 = CryptoNetworks.byId('trc20')!;

      expect(
        bep20.isValidAddress('0x55d398326f99059fF775485246999027B3197955'),
        isTrue,
      );
      expect(
        bep20.isValidAddress('TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'),
        isFalse,
      );
      expect(bep20.isValidAddress('0x123'), isFalse);
      expect(
        trc20.isValidAddress('TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'),
        isTrue,
      );
      expect(
        trc20.isValidAddress('0x55d398326f99059fF775485246999027B3197955'),
        isFalse,
      );
    });

    test('BEP20 USDT uses 18 decimals', () {
      expect(CryptoNetworks.byId('bep20')!.token('USDT')!.decimals, 18);
      expect(CryptoNetworks.byId('trc20')!.token('USDT')!.decimals, 6);
    });
  });

  group('CryptoWallet', () {
    test('round-trips through JSON and builds labels', () {
      final wallet = CryptoWallet.create(
        name: ' Trust ',
        networkId: 'bep20',
        tokenSymbol: 'USDT',
        address: '0x55d398326f99059fF775485246999027B3197955',
      );
      final restored = CryptoWallet.fromJson(wallet.toJson());

      expect(restored.name, 'Trust');
      expect(restored.label, 'USDT · BEP20');
      expect(restored.shortAddress, '0x55d3…7955');
    });

    test('clearing the address on edit stores null', () {
      final wallet = CryptoWallet.create(
        name: 'Trust',
        networkId: 'bep20',
        tokenSymbol: 'USDT',
        address: '0x55d398326f99059fF775485246999027B3197955',
      );
      expect(wallet.copyWith(address: '').address, isNull);
    });
  });

  group('Repositories', () {
    test('balance adds incomes and subtracts expenses', () async {
      const repo = CryptoEntryRepository();
      for (final (type, amount) in [
        (CashEntryType.income, 100.0),
        (CashEntryType.expense, 30.5),
        (CashEntryType.income, 0.25),
      ]) {
        await repo.add(
          CryptoEntry.create(
            walletId: 'w1',
            type: type,
            amount: amount,
            description: '',
            createdAt: DateTime(2026, 10, 1),
          ),
        );
      }
      expect(await repo.balance('w1'), closeTo(69.75, 1e-9));
      expect(await repo.balance('other'), 0);

      await repo.deleteAll('w1');
      expect(await repo.balance('w1'), 0);
    });

    test('crypto data is included in backups', () async {
      await const CryptoWalletRepository().add(
        CryptoWallet.create(name: 'T', networkId: 'bep20', tokenSymbol: 'USDT'),
      );
      final payload = await ExportService().buildPayload();
      expect(
        (payload['data'] as Map).keys,
        contains('cash_wallet_crypto_wallets'),
      );
    });
  });

  group('ChainBalanceService', () {
    final bepWallet = CryptoWallet.create(
      name: 'Trust',
      networkId: 'bep20',
      tokenSymbol: 'USDT',
      address: '0x8894E0a0c962CB723c1976a4421c95949bE2D4E3',
    );
    final tronWallet = CryptoWallet.create(
      name: 'Tron',
      networkId: 'trc20',
      tokenSymbol: 'USDT',
      address: 'TV6MuMXfmLbBqPZvBHdwFsDnQeVfnmiuSi',
    );

    test('EVM: sends balanceOf and applies 18 decimals', () async {
      late Map<String, dynamic> sent;
      final service = ChainBalanceService(
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          // 12.5 * 10^18
          return http.Response(
            jsonEncode({
              'result':
                  '0x${BigInt.parse('12500000000000000000').toRadixString(16)}',
            }),
            200,
          );
        }),
      );
      expect(await service.fetchBalance(bepWallet), 12.5);
      final call = (sent['params'] as List).first as Map<String, dynamic>;
      expect(call['to'], '0x55d398326f99059fF775485246999027B3197955');
      expect(
        call['data'],
        '0x70a08231000000000000000000000000'
        '8894e0a0c962cb723c1976a4421c95949be2d4e3',
      );
    });

    test('EVM: RPC error throws ChainBalanceException', () async {
      final service = ChainBalanceService(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'error': 'boom'}), 200),
        ),
      );
      expect(
        service.fetchBalance(bepWallet),
        throwsA(isA<ChainBalanceException>()),
      );
    });

    test('Tron: reads USDT from trc20 list with 6 decimals', () async {
      final service = ChainBalanceService(
        client: MockClient((request) async {
          expect(
            request.url.path,
            '/v1/accounts/TV6MuMXfmLbBqPZvBHdwFsDnQeVfnmiuSi',
          );
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'trc20': [
                    {'TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf': '1'},
                    {'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t': '4894284965'},
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );
      expect(await service.fetchBalance(tronWallet), 4894.284965);
    });

    test('Tron: unused account returns zero', () async {
      final service = ChainBalanceService(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'data': []}), 200),
        ),
      );
      expect(await service.fetchBalance(tronWallet), 0);
    });

    test('wallet without address throws', () async {
      final service = ChainBalanceService(
        client: MockClient((_) async => http.Response('', 500)),
      );
      expect(
        service.fetchBalance(
          CryptoWallet.create(
            name: 'X',
            networkId: 'bep20',
            tokenSymbol: 'USDT',
          ),
        ),
        throwsA(isA<ChainBalanceException>()),
      );
    });
  });

  test('amount parsing and formatting', () {
    expect(parseTokenAmount('12,5'), 12.5);
    expect(parseTokenAmount('abc'), isNull);
    expect(formatTokenAmount(12.5), '12.50');
    expect(formatTokenAmount(100), '100.00');
    expect(formatTokenAmount(12.3456), '12.3456');
  });

  testWidgets('crypto tab shows the empty state', (tester) async {
    await tester.pumpWidget(const CashWalletApp());
    await tester.pumpAndSettle();

    final tab = find.text('Cripto').evaluate().isNotEmpty
        ? find.text('Cripto')
        : find.text('Crypto');
    await tester.tap(tab.last);
    await tester.pumpAndSettle();

    final hasEmpty =
        find.text('Aún no tienes wallets cripto').evaluate().isNotEmpty ||
        find.text('You have no crypto wallets yet').evaluate().isNotEmpty;
    expect(hasEmpty, isTrue);
    expect(find.byIcon(Icons.add), findsWidgets);
  });
}
