# Wallet Screen

This document describes the main wallet screen (`lib/screens/wallet/screen.dart`), which serves as the primary interface for viewing wallet balance, transactions, and performing wallet actions.

## Overview

The wallet screen is the central hub of the CitizenWallet app. It displays:
- Wallet balance and currency information
- User profile (avatar, username)
- Transaction history
- Action buttons (Send, Receive, Plugins, etc.)
- QR code for receiving funds (when balance is zero and no transactions)
- Account switching and WalletConnect session management

## Architecture

### Main Components

1. **`WalletScreen`** (`screen.dart`)
   - Main stateful widget that orchestrates the entire screen
   - Manages lifecycle, navigation, and state coordination
   - Handles deep linking, QR scanning, and user interactions

2. **`WalletScrollView`** (`wallet_scroll_view.dart`)
   - Custom scrollable view using `CustomScrollView` with slivers
   - Implements pull-to-refresh functionality
   - Contains persistent header with wallet actions
   - Renders transaction list and empty states

3. **`WalletActions`** (`wallet_actions.dart`)
   - Persistent header component that shrinks on scroll
   - Displays profile avatar, username, balance, and action buttons
   - Animates based on scroll position using `progressiveClamp`

4. **`TransactionRow`** (`transaction_row.dart`)
   - Individual transaction list item
   - Shows transaction details: sender/receiver, amount, date, status
   - Handles profile loading and voucher display

5. **`MoreActionsSheet`** (`more_actions_sheet.dart`)
   - Bottom sheet modal for additional actions
   - Displays plugins, vouchers, and minting options

### State Management

The wallet screen uses Provider for state management:

- **`WalletState`** - Wallet data, balance, transactions, loading states
- **`ProfileState`** - Current user's profile information
- **`ProfilesState`** - Cached profiles for transaction participants
- **`VoucherState`** - Voucher data and loading states
- **`WalletConnectState`** - WalletConnect session management

### Logic Classes

- **`WalletLogic`** - Core wallet operations (loading, transactions, sending)
- **`ProfileLogic`** - Profile management and loading
- **`ProfilesLogic`** - Profile search and caching
- **`VoucherLogic`** - Voucher operations
- **`WalletKitLogic`** - WalletConnect integration

## Key Features

### 1. Wallet Loading

When the screen initializes (`onLoad()`):

```dart
await _logic.openWallet(
  _address!,
  _alias!,
  (bool hasChanged) async {
    _logic.requestWalletActions();
    await _logic.loadTransactions();
    _profileLogic.loadProfile(online: online);
    _voucherLogic.fetchVouchers();
    await _profileLogic.loadProfileLink();
    await _logic.evaluateWalletActions();
  },
);
```

**Process:**
1. Opens wallet with address and alias
2. Requests available wallet actions (plugins, vouchers, etc.)
3. Loads transaction history
4. Loads user profile
5. Fetches vouchers
6. Generates profile link for QR code
7. Evaluates which action buttons to show

### 2. Scroll Behavior

The screen uses a `CustomScrollView` with:
- **Persistent Header**: `WalletActions` component that shrinks from 420px to 300px
- **Pull-to-Refresh**: Refreshes transactions and balance
- **Infinite Scroll**: Loads more transactions when scrolling near bottom
- **Scroll-to-Top**: Tapping header scrolls to top

**Scroll Detection:**
```dart
void onScrollUpdate() {
  if (_scrollController.position.pixels >=
      _scrollController.position.maxScrollExtent - 300) {
    _logic.loadAdditionalTransactions(10);
  }
}
```

### 3. Action Buttons

The wallet displays dynamic action buttons based on configuration:

**Primary Actions (Always Visible):**
- **Send** - Navigate to send screen
- **Receive** - Navigate to receive screen

**Dynamic Actions (Context-Dependent):**
- **More** - Shows additional actions in bottom sheet
- **Vouchers** - If vouchers are available
- **Mint** - If user has minter role
- **Plugins** - If plugins are configured (shows first plugin or "More")

**Button State:**
- Disabled during loading, first load, or when sending
- Shows loading state during transaction sending
- Dynamically sized based on scroll position

### 4. Transaction Display

**Transaction States:**
- **Queued** - Failed transactions that can be retried/edited/deleted
- **In Progress** - Currently processing transactions
- **Completed** - Confirmed transactions
- **Failed** - Transactions that failed with error messages

**Transaction List:**
- Shows queued transactions first (if any)
- Displays in-progress transaction if relevant
- Lists completed transactions chronologically
- Loads more transactions on scroll (pagination)

**Transaction Row Features:**
- Profile avatars for known addresses
- Voucher indicators for voucher transactions
- Amount with currency logo
- Relative time (< 7 days) or formatted date
- Error messages for failed transactions
- Tap to view transaction details

### 5. QR Code Display

When wallet balance is zero and no transactions exist, shows QR code:

**Two Modes:**
1. **Citizen Wallet** (default) - Profile link QR code
2. **External Wallet** - Wallet address QR code

**Profile Link:**
- Generated via `ProfileLogic.loadProfileLink()`
- Links to wallet profile for easy sharing
- Includes community alias and wallet address

### 6. Deep Linking & QR Scanning

The wallet screen handles multiple deep link types:

**QR Code Formats:**
- **WalletConnect** (`wc:...`) - WalletConnect pairing
- **Plugin** - Plugin URLs
- **Standard URL** - Web URLs with plugin parameters
- **Send/Receive** - Transaction parameters
- **Voucher** - Voucher redemption
- **Deep Link** - Custom deep link actions

**QR Scan Flow:**
```dart
void handleQRScan() async {
  final result = await showCupertinoModalPopup<String?>(
    context: context,
    builder: (_) => const ScannerModal(),
  );
  
  // Parse and handle QR result
  // - WalletConnect pairing
  // - Plugin loading
  // - Send/receive navigation
  // - Voucher handling
}
```

**Deep Link Handling:**
- `plugin` - Opens plugin in webview
- `onboarding` - Onboarding flow
- Custom deep links - Navigate to specific screens

### 7. Account Switching

Users can switch between multiple accounts:

```dart
void handleOpenAccountSwitcher() async {
  final (address, alias) = await navigator.push('/wallet/$_address/accounts');
  
  if (address != _address || alias != _alias) {
    // Reset state
    _profileLogic.resetAll();
    _address = address;
    _alias = alias;
    navigator.replace('/wallet/$address?alias=$alias');
  }
}
```

**Process:**
1. Opens account selection modal
2. User selects different account
3. Resets all state (profile, vouchers, etc.)
4. Loads new wallet
5. Updates route

### 8. WalletConnect Integration

The screen manages WalletConnect sessions:

**Features:**
- Shows connection indicator when active sessions exist
- Displays disconnect modal for session management
- Handles WalletConnect QR codes
- Integrates with `WalletKitLogic`

**Session Management:**
```dart
void handleDisconnect() async {
  await showCupertinoModalPopup(
    context: context,
    builder: (context) => WalletConnectSessionsModal(
      onDisconnect: (topic) async {
        await _walletKitLogic.disconnectSession(topic: topic);
      },
    ),
  );
}
```

### 9. Failed Transaction Handling

When transactions fail, users can:

**Options:**
- **Retry** - Resubmit the transaction
- **Edit** - Modify transaction parameters
- **Delete** - Remove from queue

**Flow:**
```dart
void handleFailedTransaction(String id, bool blockSending) async {
  final option = await showCupertinoModalPopup<String?>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop('retry'),
          child: Text('Retry'),
        ),
        // ... edit, delete options
      ],
    ),
  );
  
  if (option == 'retry') {
    _logic.retryTransaction(id);
  } else if (option == 'edit') {
    _logic.prepareEditQueuedTransaction(id);
    navigator.push('/wallet/$_address/send/$addr');
  } else if (option == 'delete') {
    _logic.removeQueuedTransaction(id);
  }
}
```

### 10. Plugin Integration

Plugins can be launched from the wallet screen:

**Plugin Launch Modes:**
- **Webview** - Opens in modal webview
- **Connected Webview** - Webview with wallet integration
- **External** - Opens in external browser/app

**Connected Webview:**
- Allows plugins to request transactions
- Handles `sendto` and `calldata` URL formats
- Shows transaction confirmation modals
- Redirects back to plugin after transaction

## User Interactions

### Navigation Flows

1. **Send Flow:**
   ```
   Wallet Screen → Send Screen → Send Details → Transaction Processing
   ```

2. **Receive Flow:**
   ```
   Wallet Screen → Receive Screen (QR code display)
   ```

3. **Transaction Details:**
   ```
   Wallet Screen → Transaction Details Screen
   ```

4. **Profile Edit:**
   ```
   Wallet Screen → Profile Edit Modal
   ```

5. **Vouchers:**
   ```
   Wallet Screen → Vouchers Screen
   ```

6. **Mint:**
   ```
   Wallet Screen → Mint Screen
   ```

### Gestures

- **Pull-to-Refresh** - Refreshes transactions and balance
- **Tap Header** - Scrolls to top
- **Tap Transaction** - Opens transaction details
- **Tap Profile Avatar** - Opens profile edit
- **Long Press** - (Future: Copy address, etc.)

## State Lifecycle

### Initialization

1. `initState()` - Sets up observers, controllers, logic instances
2. `onLoad()` - Loads wallet, transactions, profile
3. `WidgetsBindingObserver` - Handles app lifecycle changes

### Updates

- `didUpdateWidget()` - Handles route parameter changes
- State changes trigger rebuilds via Provider
- Scroll position updates trigger header animations

### Cleanup

- `dispose()` - Removes observers, controllers, pauses fetching
- Logic instances handle their own cleanup

## Performance Considerations

### Optimizations

1. **Lazy Loading:**
   - Transactions loaded in batches
   - Profiles loaded on-demand
   - Images cached via profile service

2. **State Selectors:**
   - Uses `context.select()` for granular rebuilds
   - Only rebuilds components when relevant state changes

3. **Scroll Performance:**
   - Uses `SliverList` for efficient scrolling
   - Transactions rendered on-demand
   - Profile images loaded asynchronously

4. **Background Operations:**
   - Transaction fetching paused when screen not visible
   - Profile loading paused during navigation
   - Event service manages connection lifecycle

## Error Handling

### Network Errors

- Shows offline banner when disconnected
- Retries failed transactions
- Caches data for offline viewing

### Transaction Errors

- Displays error messages in transaction rows
- Allows retry/edit/delete for failed transactions
- Shows toast notifications for critical errors

### Loading Errors

- Graceful degradation when data unavailable
- Loading indicators during async operations
- Error states with retry options

## Configuration

The wallet screen behavior is controlled by:

- **Community Config** - Defines available plugins, actions
- **Wallet State** - Current wallet, balance, transactions
- **User Permissions** - Minter role, plugin access
- **Network Status** - Online/offline state

## Related Documentation

- [Send Flow](./send_flow.md) - Token sending process
- [Tip Flow](./tip_flow.md) - Tipping functionality
- [State Management](../docs/state.md) - State management patterns
- [Models](../docs/models.md) - Data models

