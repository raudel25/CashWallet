/// Blockchain family. Networks of the same family share the same balance
/// reading logic (EVM: `eth_call balanceOf`, Tron: TronGrid).
enum ChainFamily { evm, tron }

class TokenContract {
  const TokenContract({
    required this.symbol,
    required this.address,
    required this.decimals,
  });

  final String symbol;
  final String address;
  final int decimals;
}

/// How to read Transfer logs on an EVM network with `eth_getLogs`. Public
/// nodes cap the block range per request, so history is read in chunks.
class EvmLogsConfig {
  const EvmLogsConfig({
    required this.rpcUrl,
    required this.blockRange,
    required this.initialLookbackBlocks,
    this.maxChunks = 40,
  });

  /// Node that accepts `eth_getLogs` (not all public nodes do).
  final String rpcUrl;

  /// Max blocks per request accepted by the node.
  final int blockRange;

  /// How far back the first sync looks (≈ 2 days).
  final int initialLookbackBlocks;

  /// Max requests per sync. Larger gaps only read the most recent blocks.
  final int maxChunks;
}

class CryptoNetwork {
  const CryptoNetwork({
    required this.id,
    required this.name,
    required this.standard,
    required this.family,
    required this.rpcUrl,
    required this.tokens,
    this.evmLogs,
  });

  final String id;
  final String name;

  /// Short label users recognise, e.g. "BEP20", "TRC20".
  final String standard;
  final ChainFamily family;
  final String rpcUrl;
  final List<TokenContract> tokens;

  /// Null on EVM networks whose free public nodes don't serve logs.
  final EvmLogsConfig? evmLogs;

  /// Whether transfers can be imported. Tron uses TronGrid's full history.
  bool get supportsHistory => family == ChainFamily.tron || evmLogs != null;

  TokenContract? token(String symbol) {
    for (final token in tokens) {
      if (token.symbol == symbol) return token;
    }
    return null;
  }

  static final _evmAddress = RegExp(r'^0x[a-fA-F0-9]{40}$');
  static final _tronAddress = RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$');

  bool isValidAddress(String address) {
    switch (family) {
      case ChainFamily.evm:
        return _evmAddress.hasMatch(address);
      case ChainFamily.tron:
        return _tronAddress.hasMatch(address);
    }
  }
}

/// Supported networks. Adding an EVM network only requires a new entry here.
/// Contracts verified on-chain (symbol + decimals) and log limits tested on
/// 2026-10-31.
class CryptoNetworks {
  static const List<CryptoNetwork> all = [
    CryptoNetwork(
      id: 'bep20',
      name: 'BNB Smart Chain',
      standard: 'BEP20',
      family: ChainFamily.evm,
      rpcUrl: 'https://bsc-dataseed.binance.org',
      // ~192k blocks/day. bsc-dataseed rejects eth_getLogs.
      evmLogs: EvmLogsConfig(
        rpcUrl: 'https://bsc-rpc.publicnode.com',
        blockRange: 49999,
        initialLookbackBlocks: 400000,
      ),
      tokens: [
        TokenContract(
          symbol: 'USDT',
          address: '0x55d398326f99059fF775485246999027B3197955',
          decimals: 18,
        ),
        TokenContract(
          symbol: 'USDC',
          address: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
          decimals: 18,
        ),
      ],
    ),
    CryptoNetwork(
      id: 'trc20',
      name: 'Tron',
      standard: 'TRC20',
      family: ChainFamily.tron,
      rpcUrl: 'https://api.trongrid.io',
      tokens: [
        TokenContract(
          symbol: 'USDT',
          address: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
          decimals: 6,
        ),
      ],
    ),
    CryptoNetwork(
      id: 'erc20',
      name: 'Ethereum',
      standard: 'ERC20',
      family: ChainFamily.evm,
      rpcUrl: 'https://ethereum-rpc.publicnode.com',
      // ~7.2k blocks/day.
      evmLogs: EvmLogsConfig(
        rpcUrl: 'https://ethereum-rpc.publicnode.com',
        blockRange: 9999,
        initialLookbackBlocks: 15000,
      ),
      tokens: [
        TokenContract(
          symbol: 'USDT',
          address: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
          decimals: 6,
        ),
        TokenContract(
          symbol: 'USDC',
          address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
          decimals: 6,
        ),
      ],
    ),
    CryptoNetwork(
      id: 'polygon',
      name: 'Polygon',
      standard: 'Polygon',
      family: ChainFamily.evm,
      rpcUrl: 'https://polygon-bor-rpc.publicnode.com',
      // ~57k blocks/day.
      evmLogs: EvmLogsConfig(
        rpcUrl: 'https://polygon-bor-rpc.publicnode.com',
        blockRange: 9999,
        initialLookbackBlocks: 115000,
      ),
      tokens: [
        TokenContract(
          symbol: 'USDT',
          address: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
          decimals: 6,
        ),
        TokenContract(
          symbol: 'USDC',
          address: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
          decimals: 6,
        ),
      ],
    ),
    CryptoNetwork(
      id: 'arbitrum',
      name: 'Arbitrum One',
      standard: 'Arbitrum',
      family: ChainFamily.evm,
      rpcUrl: 'https://arb1.arbitrum.io/rpc',
      // No evmLogs: free public nodes require a token for log queries.
      tokens: [
        TokenContract(
          symbol: 'USDT',
          address: '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
          decimals: 6,
        ),
        TokenContract(
          symbol: 'USDC',
          address: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
          decimals: 6,
        ),
      ],
    ),
  ];

  static CryptoNetwork? byId(String id) {
    for (final network in all) {
      if (network.id == id) return network;
    }
    return null;
  }
}
