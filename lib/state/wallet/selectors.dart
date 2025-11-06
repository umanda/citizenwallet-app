import 'package:citizenwallet/models/wallet.dart';
import 'package:citizenwallet/state/wallet/state.dart';
import 'package:collection/collection.dart';
import 'package:citizenwallet/services/config/config.dart';

double selectWalletBalance(WalletState state) {
  if (state.wallet == null) {
    return 0.0;
  }

  final Map<String, String> processed = {};

  final pendingBalance =
      state.transactions.where((tx) => tx.isProcessing).fold(0.0, (sum, tx) {
    if (processed.containsKey(tx.hash)) {
      return sum;
    }

    processed[tx.hash] = tx.hash;

    return tx.isIncoming(state.wallet!.account)
        ? sum + (double.tryParse(tx.amount) ?? 0.0)
        : sum - (double.tryParse(tx.amount) ?? 0.0);
  });

  final balance = state.wallet != null
      ? double.tryParse(state.wallet!.balance) ?? 0.0
      : 0.0;

  return balance + pendingBalance;
}

// selectShouldBlockSending returns true if there is a pending transaction that is outgoing
bool selectShouldBlockSending(WalletState state) {
  if (state.wallet == null) {
    return true;
  }
  if (!state.ready) {
    return true;
  }

  if (state.wallet?.locked == true) {
    return true;
  }

  if (state.wallet?.doubleBalance == 0.0 &&
      state.config!.getTopUpPlugin() == null) {
    return true;
  }

  if (state.config?.online == false) {
    return true;
  }

  return false;
}

bool selectHasProcessingTransactions(WalletState state) =>
    state.transactions.any((tx) => tx.isProcessing);

List<CWWallet> selectSortedWalletsByAlias(WalletState state) =>
    state.wallets.toList()
      ..sort((a, b) => a.alias.toLowerCase().compareTo(b.alias.toLowerCase()));

Map<String, List<CWWallet>> selectSortedGroupedWalletsByAlias(
        WalletState state) =>
    state.wallets
        .where((w) {
          final wallet = state.wallet;
          if (wallet == null) {
            return true;
          }

          return '${w.alias}:${w.account}' !=
              '${wallet.alias}:${wallet.account}';
        })
        .sortedBy((w) => w.alias.toLowerCase())
        .groupListsBy((w) => w.alias.toLowerCase());

ActionButton? selectActionButtonToShow(WalletState state) {
  if (state.walletActions.isEmpty) {
    return null;
  }

  final moreButton = state.walletActions.firstWhereOrNull(
    (action) => action.buttonType == ActionButtonType.more,
  );

  if (moreButton != null) {
    // Count items that would be in the More menu
    int moreMenuItemsCount = 0;
    
    // Count vouchers (always 1 if present)
    final hasVouchers = state.walletActions.any(
      (action) => action.buttonType == ActionButtonType.vouchers,
    );
    if (hasVouchers) moreMenuItemsCount++;
    
    // Count minter (1 if present)
    final hasMinter = state.walletActions.any(
      (action) => action.buttonType == ActionButtonType.minter,
    );
    if (hasMinter) moreMenuItemsCount++;
    
    // Count plugins (excluding featured plugin displayed as button)
    final plugins = selectVisiblePlugins(state);
    final featuredPlugins = selectFeaturedPlugins(state);
    final displayedFeaturedPlugin = featuredPlugins.isNotEmpty ? featuredPlugins.first : null;
    
    final pluginsToShow = displayedFeaturedPlugin != null
        ? plugins.where((plugin) => plugin.url != displayedFeaturedPlugin.url).toList()
        : plugins;
    
    // If plugins action exists, count the plugins that would be shown
    final hasPlugins = state.walletActions.any(
      (action) => action.buttonType == ActionButtonType.plugins,
    );
    if (hasPlugins && pluginsToShow.isNotEmpty) {
      moreMenuItemsCount += pluginsToShow.length;
    }
    
    // If More menu would be empty, don't show More button
    if (moreMenuItemsCount == 0) {
      // Return the last action (excluding More button)
      return state.walletActions
          .where((action) => action.buttonType != ActionButtonType.more)
          .lastOrNull;
    }
    
    // If More menu would only have 1 item, show that item directly instead
    if (moreMenuItemsCount == 1) {
      // Return the single action that would be in More menu
      if (hasVouchers) {
        return state.walletActions.firstWhere(
          (action) => action.buttonType == ActionButtonType.vouchers,
        );
      }
      if (hasMinter) {
        return state.walletActions.firstWhere(
          (action) => action.buttonType == ActionButtonType.minter,
        );
      }
      if (hasPlugins && pluginsToShow.isNotEmpty) {
        return state.walletActions.firstWhere(
          (action) => action.buttonType == ActionButtonType.plugins,
        );
      }
    }
    
    // Otherwise, show More button
    return moreButton;
  }

  return state.walletActions.last;
}

List<PluginConfig> selectVisiblePlugins(WalletState state) =>
    (state.wallet?.plugins ?? []).where((plugin) => !plugin.hidden).toList();

List<PluginConfig> selectFeaturedPlugins(WalletState state) =>
    (state.wallet?.plugins ?? [])
        .where((plugin) => !plugin.hidden && plugin.featured)
        .toList();
