# Tipping Flow

This document describes how the tipping feature works in the CitizenWallet app. The tip flow allows users to send an additional tip to a recipient after completing a main transaction.

## Overview

The tipping flow is a two-step process:
1. **Main Transaction** - User sends tokens to a recipient
2. **Tip Transaction** - After the main transaction succeeds, user can optionally send an additional tip to the same recipient

## How Tipping is Initiated

Tipping can be initiated in two ways:

### 1. From QR Codes / Deep Links

When scanning a QR code or opening a deep link that includes a `tipTo` parameter, the app automatically sets up the tip flow.

**QR Code Format:**
```
https://app.citizenwallet.xyz/?sendto=0x123...@community&amount=100&tipTo=0x456...
```

**Parameters:**
- `tipTo` - The address to receive the tip (required for tip flow)
- `tipAmount` - Optional tip amount (currently not used in UI)
- `tipDescription` - Optional tip description (currently not used in UI)

**Code Flow:**
```dart
// In WalletLogic.updateFromCapture()
if (parsedData.tip != null) {
  _state.setTipTo(parsedData.tip!.to);
  _state.setHasTip(true);
}
```

### 2. From Progress Screen

After a successful transaction, if `hasTip` is `true` in the wallet state, the progress screen shows a "Send Tip" button instead of auto-closing.

## State Management

### WalletState Properties

- `tipTo: String?` - The address that will receive the tip
- `hasTip: bool` - Whether the tip flow should be enabled

### Setting Tip State

```dart
// Set tip recipient
walletLogic.setTipTo(address);

// Enable tip flow
walletLogic.setHasTip(true);

// Clear tip state (after tip is sent)
walletLogic.setHasTip(false);
walletLogic.setTipTo(null);
```

## Tip Flow Sequence

### Step 1: Main Transaction

1. User scans QR code or opens deep link with `tipTo` parameter
2. `tipTo` is stored in `WalletState` and `hasTip` is set to `true`
3. User completes normal send flow (who → amount → progress)
4. Main transaction is sent and processed

### Step 2: Progress Screen Behavior

In `send_progress.dart`, when the transaction succeeds:

```dart
if (inProgressTransaction.state == TransactionState.success) {
  final hasTip = context.read<WalletState>().hasTip;
  if (!hasTip) {
    // Auto-close after 5 seconds
    handleStartCloseScreenTimer(context);
  }
  // If hasTip is true, show "Send Tip" button instead
}
```

**UI Behavior:**
- If `hasTip == false`: Shows "Dismiss" button, auto-closes after 5 seconds
- If `hasTip == true`: Shows "Send Tip" button and "Dismiss" button, does NOT auto-close

### Step 3: Tip Details Screen

When user clicks "Send Tip" button:

**Route:** `/wallet/:account/send/:to/tip`

**Screen:** `TipDetailsScreen` (`lib/screens/send/tip_details.dart`)

**Initialization:**
```dart
@override
void initState() {
  super.initState();
  final tipTo = context.read<WalletState>().tipTo;
  
  if (tipTo != null) {
    // Load profile for tip recipient
    widget.profilesLogic.getProfile(tipTo).then((profile) {
      if (profile != null) {
        widget.profilesLogic.selectProfile(profile);
      }
    });
  }
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final tipTo = context.read<WalletState>().tipTo;
  if (tipTo != null) {
    widget.walletLogic.setHasTip(true);
    widget.walletLogic.setHasAddress(true);
  }
}
```

**Key Differences from Regular Send:**
- Title shows "Send Tip" instead of "Send"
- Uses `tipTo` from state as the recipient (not from address controller)
- Creates `SendTransaction` with `tipAmount`, `tipTo`, and `tipDescription`
- After sending, clears tip state

### Step 4: Sending the Tip

When user swipes to complete the tip:

```dart
void handleSend(BuildContext context, String? selectedAddress, String? tipTo) {
  // Validate tipTo is present
  if (tipTo == null) {
    return;
  }
  
  // Create tip transaction
  final sendTip = SendTransaction(
    tipAmount: walletLogic.amountController.value.text,
    tipTo: tipTo,
    tipDescription: walletLogic.messageController.value.text.trim(),
  );
  
  // Send the tip transaction
  walletLogic.sendTransaction(
    sendTip.tipAmount!,
    sendTip.tipTo!,
    message: sendTip.tipDescription!,
  );
  
  // Clear tip state
  widget.walletLogic.setHasTip(false);
  widget.walletLogic.setHasAddress(false);
  widget.walletLogic.setTipTo(null);
  
  // Navigate to progress screen
  navigator.push('/wallet/${walletLogic.account}/send/$toAccount/progress');
}
```

### Step 5: Tip Progress

The tip transaction goes through the same progress screen as the main transaction. After the tip succeeds, `hasTip` is now `false`, so the screen will auto-close after 5 seconds.

## SendTransaction Model

The `SendTransaction` model supports both regular transactions and tips:

```dart
class SendTransaction {
  // Regular transaction fields
  String? to;
  String? amount;
  String? description;
  
  // Tip transaction fields
  String? tipTo;
  String? tipAmount;
  String? tipDescription;
}
```

## QR Code Parsing

When parsing QR codes, tip information is extracted:

```dart
// In lib/utils/qr.dart
ParsedQRData parseSendtoUrl(String raw) {
  final tipToParam = receiveUrl.queryParameters['tipTo'];
  final tipAmountParam = receiveUrl.queryParameters['tipAmount'];
  final tipDescriptionParam = receiveUrl.queryParameters['tipDescription'];
  
  final tip = tipToParam != null
      ? SendDestination(
          to: tipToParam,
          amount: tipAmountParam,
          description: tipDescriptionParam,
        )
      : null;
  
  return ParsedQRData(
    address: address,
    amount: amountParam,
    description: descriptionParam,
    tip: tip,  // Tip info included in parsed data
  );
}
```

## Deep Link Support

Deep links can include tip information:

**URL Format:**
```
https://app.citizenwallet.xyz/?sendto=0x123...@community&amount=100&tipTo=0x456...
```

**Router Parsing:**
```dart
// In lib/router/router.dart
final tipTo = uri.queryParameters['tipTo'];
if (sendTo != null) {
  String params = 'sendto=$sendTo';
  if (tipTo != null) {
    params += '&tipTo=$tipTo';
  }
  // ... other params
}
```

## Key Files

- `lib/screens/send/tip_details.dart` - Tip entry screen
- `lib/screens/send/send_progress.dart` - Progress screen with tip button
- `lib/state/wallet/state.dart` - `tipTo` and `hasTip` state
- `lib/state/wallet/logic.dart` - Tip state management methods
- `lib/models/send_transaction.dart` - Transaction model with tip fields
- `lib/utils/qr.dart` - QR code parsing with tip support
- `lib/router/router.dart` - Deep link routing with tip parameter

## User Experience Flow

1. **Scan QR with tip**: User scans QR code containing `tipTo` parameter
2. **Send main transaction**: User completes normal send flow
3. **Transaction succeeds**: Progress screen shows "Send Tip" button (instead of auto-closing)
4. **Enter tip**: User clicks "Send Tip", enters tip amount and description
5. **Send tip**: User swipes to send tip transaction
6. **Tip succeeds**: Progress screen shows success, auto-closes after 5 seconds

## Important Notes

- The tip is a **separate transaction** from the main transaction
- Tip recipient (`tipTo`) is set from QR/deep link, not from user input
- After sending the tip, the tip state is cleared
- If `hasTip` is `true`, the progress screen does NOT auto-close, allowing user to send tip
- The tip flow uses the same transaction infrastructure as regular sends
- Tip amount and description are entered by the user in `TipDetailsScreen`

