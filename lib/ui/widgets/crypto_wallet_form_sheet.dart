import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/crypto_network.dart';
import '../../models/crypto_wallet.dart';
import 'crypto_movement_form_sheet.dart';

class CryptoWalletFormResult {
  const CryptoWalletFormResult({
    required this.wallet,
    required this.initialBalance,
  });

  final CryptoWallet wallet;

  /// Only used when creating a wallet. Zero when not provided.
  final double initialBalance;
}

class CryptoWalletFormSheet extends StatefulWidget {
  const CryptoWalletFormSheet({super.key, this.initialWallet});

  /// If provided, the sheet works in edit mode (network and token locked).
  final CryptoWallet? initialWallet;

  bool get isEditing => initialWallet != null;

  @override
  State<CryptoWalletFormSheet> createState() => _CryptoWalletFormSheetState();
}

class _CryptoWalletFormSheetState extends State<CryptoWalletFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  final TextEditingController _initialBalanceController =
      TextEditingController();
  late CryptoNetwork _network;
  late String _tokenSymbol;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialWallet;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _addressController = TextEditingController(text: initial?.address ?? '');
    _network = initial?.network ?? CryptoNetworks.all.first;
    _tokenSymbol = initial?.tokenSymbol ?? _network.tokens.first.symbol;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  void _onNetworkChanged(CryptoNetwork? network) {
    if (network == null) return;
    setState(() {
      _network = network;
      if (network.token(_tokenSymbol) == null) {
        _tokenSymbol = network.tokens.first.symbol;
      }
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final initial = widget.initialWallet;
    final wallet = initial == null
        ? CryptoWallet.create(
            name: _nameController.text,
            networkId: _network.id,
            tokenSymbol: _tokenSymbol,
            address: _addressController.text,
          )
        : initial.copyWith(
            name: _nameController.text,
            address: _addressController.text,
          );

    Navigator.of(context).pop(
      CryptoWalletFormResult(
        wallet: wallet,
        initialBalance: parseTokenAmount(_initialBalanceController.text) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.t(
                          isEditing
                              ? 'crypto_edit_wallet'
                              : 'crypto_new_wallet',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.t('crypto_wallet_name'),
                    hintText: context.t('crypto_wallet_name_hint'),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? context.t('crypto_wallet_name_required')
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CryptoNetwork>(
                  initialValue: _network,
                  decoration: InputDecoration(
                    labelText: context.t('crypto_network'),
                  ),
                  items: CryptoNetworks.all
                      .map(
                        (network) => DropdownMenuItem(
                          value: network,
                          child: Text('${network.standard} · ${network.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: isEditing ? null : _onNetworkChanged,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // Rebuild when the network changes so the token resets.
                  key: ValueKey(_network.id),
                  initialValue: _tokenSymbol,
                  decoration: InputDecoration(
                    labelText: context.t('crypto_token'),
                  ),
                  items: _network.tokens
                      .map(
                        (token) => DropdownMenuItem(
                          value: token.symbol,
                          child: Text(token.symbol),
                        ),
                      )
                      .toList(),
                  onChanged: isEditing
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _tokenSymbol = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: context.t('crypto_address'),
                    helperText: context.t('crypto_address_helper'),
                    helperMaxLines: 2,
                  ),
                  validator: (value) {
                    final address = value?.trim() ?? '';
                    if (address.isEmpty) return null;
                    return _network.isValidAddress(address)
                        ? null
                        : context.t(
                            'crypto_address_invalid',
                            params: {'network': _network.standard},
                          );
                  },
                ),
                if (!isEditing) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _initialBalanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.t('crypto_initial_balance'),
                      helperText: context.t('crypto_initial_balance_helper'),
                      helperMaxLines: 2,
                      suffixText: _tokenSymbol,
                    ),
                    validator: (value) {
                      final raw = value?.trim() ?? '';
                      if (raw.isEmpty) return null;
                      final amount = parseTokenAmount(raw);
                      return amount == null || amount < 0
                          ? context.t('crypto_amount_invalid')
                          : null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.t('common_cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.save),
                        label: Text(context.t('common_save')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
