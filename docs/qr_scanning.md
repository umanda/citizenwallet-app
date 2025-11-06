# QR Code Scanning Implementation

This document describes how QR code scanning is implemented in the CitizenWallet app.

## Overview

The app uses the `mobile_scanner` package to scan QR codes. Scanned QR codes are parsed and handled based on their format, supporting multiple QR code types including wallet addresses, EIP-681 URIs, send/receive URLs, calldata transactions, and WalletConnect connections.

## Components

### Scanner Widgets

#### `ScannerModal` (`lib/widgets/scanner/scanner_modal.dart`)

A full-screen modal that displays the camera scanner interface. This is the primary entry point for QR scanning in the app.

**Features:**
- Full-screen camera view with QR code detection
- Torch/flashlight toggle (if available)
- Manual text entry option (when `confirm` is true)
- Success animation on detection
- Lifecycle-aware (pauses/resumes with app state)

**Usage:**
```dart
final result = await showCupertinoModalPopup<String?>(
  context: context,
  builder: (_) => const ScannerModal(
    modalKey: 'wallet-qr-scanner',
  ),
);
```

The modal returns the scanned QR code string, or `null` if dismissed.

#### `Scanner` (`lib/widgets/scanner/scanner.dart`)

A smaller, embedded scanner widget that can be used within other screens. Similar functionality to `ScannerModal` but designed for inline use.

### QR Code Parsing

#### `parseQRFormat` (`lib/utils/qr.dart`)

Detects the format of a QR code string and returns a `QRFormat` enum value:

- `address` - Plain Ethereum address (starts with `0x`)
- `eip681` - EIP-681 URI format (`ethereum:address@chainId`)
- `eip681Transfer` - EIP-681 transfer format (`ethereum:.../transfer`)
- `receiveUrl` - Receive URL with compressed params
- `sendtoUrl` - Send-to URL format (`https://...?sendto=...`)
- `sendtoUrlWithEIP681` - Send-to URL with embedded EIP-681
- `calldataUrl` - Calldata transaction URL (`https://...?calldata=...`)
- `plugin` - Plugin URL format
- `url` - Generic HTTP/HTTPS URL
- `unsupported` - Unknown format

#### `parseQRCode` (`lib/utils/qr.dart`)

Parses a QR code string based on its format and returns a `ParsedQRData` object containing:
- `address` - Recipient address
- `amount` - Transaction amount (if specified)
- `description` - Transaction description/message
- `alias` - Community alias
- `tip` - Tip information (if present)
- `calldata` - Contract call data (for calldata transactions)

## QR Code Formats

### 1. Plain Address
```
0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5
```
- Directly used as recipient address
- No amount or description

### 2. EIP-681 Format
```
ethereum:0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5@1?value=1000000000000000000
```
- Standard Ethereum URI format
- Supports chain ID in address (`address@chainId`)
- Amount in `value` parameter (in wei)

### 3. EIP-681 Transfer
```
ethereum:0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5/transfer?address=0x...&uint256=100
```
- ERC-20 token transfer format
- `address` parameter specifies token contract
- `uint256` parameter specifies amount

### 4. Send-to URL
```
https://app.citizenwallet.xyz/?sendto=username@community&amount=100&description=Hello
```
- Community-specific send format
- Supports username resolution
- Includes amount and description
- Can include tip information (`tipTo`, `tipAmount`, `tipDescription`)

### 5. Calldata URL
```
https://app.citizenwallet.xyz/?calldata=0x...&address=0x...&value=0
```
- For smart contract interactions
- `calldata` contains the function call data
- `address` is the contract address
- `value` is the ETH value to send

### 6. Receive URL
```
https://app.citizenwallet.xyz/#/?receiveParams=compressed_data
```
- Compressed receive parameters
- Used for generating receive QR codes
- Can be decompressed to extract address, amount, alias, etc.

### 7. Plugin URL
```
https://app.citizenwallet.xyz/#/?dl=plugin&alias=community&plugin=encoded_url
```
- Opens a plugin/webview
- `alias` specifies the community
- `plugin` contains the encoded plugin URL

## Scanning Flow

### 1. Wallet Screen (`lib/screens/wallet/screen.dart`)

When a QR code is scanned from the wallet screen:

```910:1003:lib/screens/wallet/screen.dart
  void handleQRScan() async {
    _profileLogic.pause();
    _profilesLogic.pause();
    _voucherLogic.pause();

    final result = await showCupertinoModalPopup<String?>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ScannerModal(
        modalKey: 'wallet-qr-scanner',
      ),
    );

    if (result == null) {
      _profileLogic.resume();
      _profilesLogic.resume();
      _voucherLogic.pause();
      return;
    }

    if (result.startsWith('wc:')) {
      try {
        if (_walletKitLogic.connectClient == null) {
          await _walletKitLogic.initialize();
        }

        await _walletKitLogic.registerWallet(_address!);
        await _walletKitLogic.pairWithDapp(result);
        await _walletKitLogic.approveSession();

        _profileLogic.resume();
        _profilesLogic.resume();
        _voucherLogic.resume();
        return;
      } catch (e) {
        _profileLogic.resume();
        _profilesLogic.resume();
        _voucherLogic.resume();
        return;
      }
    }

    final format = parseQRFormat(result);
    if (format == QRFormat.plugin) {
      final parsed = parseQRCode(result);
      final pluginUrl = parsed.description;
      final alias = parsed.alias;
      if (pluginUrl == null || alias == null) {
        _profileLogic.resume();
        _profilesLogic.resume();
        _voucherLogic.resume();
        return;
      }

      if (alias != _alias) {
        _address = null;
        _alias = null;
        _deepLink = 'plugin';
        _deepLinkParams = encodeParams(pluginUrl);

        final (address, newAlias) = await handleLoadFromParams(
          null,
          overrideAlias: alias,
        );

        if (address == null || newAlias == null) {
          _profileLogic.resume();
          _profilesLogic.resume();
          _voucherLogic.resume();
          return;
        }

        _address = address;
        _alias = newAlias;

        onLoad();
        return;
      }

      final pluginConfig = await _logic.getPluginConfig(alias, pluginUrl);
      if (pluginConfig == null) {
        _profileLogic.resume();
        _profilesLogic.resume();
        _voucherLogic.resume();
        return;
      }

      await handlePlugin(pluginConfig);

      _profileLogic.resume();
      _profilesLogic.resume();
      _voucherLogic.resume();
      return;
    }
```

**Handling Steps:**
1. **WalletConnect** - If QR starts with `wc:`, initiates WalletConnect pairing
2. **Plugin URLs** - Opens plugin/webview if format is `plugin`
3. **Regular URLs** - Opens connected webview modal for generic URLs
4. **Address/Transaction QR codes** - Parses and navigates to send screen or updates receive screen

### 2. Send Screen (`lib/state/wallet/logic.dart`)

When scanning from the send screen, the QR code is parsed and used to populate the send form:

```1760:1848:lib/state/wallet/logic.dart
  Future<String?> handleQRScan(String raw) async {
    try {
      final format = parseQRFormat(raw);

      if (format == QRFormat.unsupported) {
        _state.setInvalidScanMessage('Unsupported QR code format');
        return null;
      }

      if (format == QRFormat.voucher) {
        _state.setInvalidScanMessage('Vouchers cannot be used for transfers');
        return null;
      }

      if (format == QRFormat.url && !raw.contains('sendto=') && !raw.contains('calldata=')) {
        _state.setInvalidScanMessage('Invalid QR code format');
        return null;
      }

      final parsedData = parseQRCode(raw);

      if (parsedData.address.isEmpty) {
        throw QREmptyException();
      }

      if (format == QRFormat.eip681 || format == QRFormat.eip681Transfer) {
        final url = Uri.parse(raw);
        final chainIdParam = url.authority.split('@').last;
        final chainId = int.tryParse(chainIdParam);

        if (chainId != null) {
          final token = _wallet.currency;
          if (token.chainId != chainId) {
            _notificationsLogic
                .show('Wrong chain ID. Expected ${token.chainId}, got $chainId');
            throw QRInvalidException();
          }
        }

        try {
          final tokenAddress = url.queryParameters['address'];
          if (tokenAddress != null) {
            final token = _wallet.currency;
            if (token.contract != null &&
                token.contract!.toLowerCase() != tokenAddress.toLowerCase()) {
              _notificationsLogic
                  .show('Wrong token contract. Expected ${token.contract}, got $tokenAddress');
              throw QRInvalidException();
            }
          }
        } catch (e) {
          if (e is QRInvalidException) {
            rethrow;
          }
          _notificationsLogic
              .show('Invalid token contract or community configuration');
          throw QRInvalidException();
        }
      }

      if (parsedData.amount != null) {
        if (format == QRFormat.eip681Transfer) {
          final amount = fromDoubleUnit(
            parsedData.amount!,
            decimals: _wallet.currency.decimals,
          );
          _amountController.text = amount;
        } else {
          _amountController.text = parsedData.amount!;
        }
        updateAmount();
      }

      String addressToUse = '';
      try {
        EthereumAddress.fromHex(parsedData.address).hexEip55;
        addressToUse = parsedData.address;
      } catch (_) {
        String username = parsedData.address;
        ProfileV1? profile = await _wallet.getProfileByUsername(username);
        if (profile != null) {
          addressToUse = profile.account;
        } else {
          addressToUse = parsedData.address;
        }
      }

      updateAddressFromHexCapture(addressToUse);

      if (parsedData.description != null) {
        _messageController.text = parsedData.description!;
      } else {
        _messageController.text = parseMessageFromReceiveParams(raw) ?? '';
      }

      // Handle tip information if present
      if (parsedData.tip != null) {
        _state.setTipTo(parsedData.tip!.to);
        _state.setHasTip(true);
      }

      return addressToUse;
    } on QREmptyException catch (e) {
      _state.setInvalidScanMessage(e.message);
    } on QRInvalidException catch (e) {
      _state.setInvalidScanMessage(e.message);
    } on QRAliasMismatchException catch (e) {
      _state.setInvalidScanMessage(e.message);
    } on QRMissingAddressException catch (e) {
      _state.setInvalidScanMessage(e.message);
    } catch (_) {
      //
    }

    return null;
  }
```

**Processing Steps:**
1. Validates QR format
2. Parses QR data (address, amount, description, etc.)
3. Validates chain ID for EIP-681 formats
4. Validates token contract for token transfers
5. Resolves username to address if needed
6. Populates form fields (amount, address, description)
7. Handles tip information if present

### 3. Connected WebView (`lib/widgets/webview/connected_webview_modal.dart`)

When a webview detects a QR code format in navigation, it intercepts and shows a confirmation modal:

```85:119:lib/widgets/webview/connected_webview_modal.dart
  Future<NavigationActionPolicy?> shouldOverrideUrlLoading(
      InAppWebViewController controller, NavigationAction action) async {
    final uri = Uri.parse(action.request.url.toString());

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      widget.walletLogic.launchPluginUrl(uri.toString());

      return NavigationActionPolicy.CANCEL;
    }

    if (uri.toString().startsWith(widget.closeUrl)) {
      handleClose();

      return NavigationActionPolicy.CANCEL;
    }

    if (uri.toString().startsWith(widget.redirectUrl) &&
        !uri.toString().startsWith(widget.pluginUrl)) {
      final format = parseQRFormat(uri.toString());

      switch (format) {
        case QRFormat.sendtoUrl:
          handleDisplaySendActionModal(uri);
          break;
        case QRFormat.calldataUrl:
          handleDisplayCallDataActionModal(uri);
          break;
        default:
      }

      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }
```

**WebView Actions:**
- **Send-to URLs** - Shows `ConnectedWebViewSendModal` for confirmation
- **Calldata URLs** - Shows `ConnectedWebViewCallDataModal` for contract calls
- **Close URLs** - Closes the webview modal

## Transaction Modals

### Send Modal (`lib/widgets/webview/connected_webview_send_modal.dart`)

Displays transaction details and allows user to confirm:
- Recipient profile information
- Amount and currency
- Description
- Slide-to-confirm interaction

On confirmation, executes the transaction and redirects to success URL with transaction hash.

### Calldata Modal (`lib/widgets/webview/connected_webview_calldata_modal.dart`)

Displays contract call details:
- Contract address
- Value (ETH amount)
- Calldata (encoded function call)
- Slide-to-confirm interaction

On confirmation, executes the contract call and redirects to success URL with transaction hash.

## Error Handling

The app defines several QR-related exceptions:

- `QREmptyException` - QR code has no address
- `QRInvalidException` - QR code format is invalid
- `QRAliasMismatchException` - QR code alias doesn't match current community
- `QRMissingAddressException` - QR code is missing required address

These exceptions are caught and displayed to the user via the wallet state's `invalidScanMessage`.

## Lifecycle Management

Both `Scanner` and `ScannerModal` implement `WidgetsBindingObserver` to handle app lifecycle changes:

- **Paused/Hidden** - Scanner stops
- **Resumed** - Scanner restarts and re-subscribes to barcode events

This ensures the camera is properly managed when the app goes to background.

## Dependencies

- `mobile_scanner` - QR code scanning
- `flutter_inappwebview` - WebView for plugin URLs
- `web3dart` - Ethereum address validation
- `go_router` - Navigation

## Testing

QR parsing logic is tested in `test/services/wallet/qr_test.dart`. The tests cover:
- Format detection
- Parsing different QR formats
- Edge cases and error handling

