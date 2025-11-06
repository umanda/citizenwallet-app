# Token Sending Flow

This document describes the three-step token sending flow in the CitizenWallet app.

## Overview

The token sending flow consists of three main steps:
1. **Who** - Select recipient (address/profile)
2. **Amount + Description** - Enter amount and optional message
3. **Progress / Success** - Transaction processing and confirmation

## Step 1: Who (`send_to.dart`)

**Route:** `/wallet/:account/send`

**Purpose:** Select the recipient for the token transfer.

### Features
- **Search by username/address**: Text input field with real-time profile search
- **QR Code scanning**: Scan QR codes to capture recipient address
- **NFC reading**: Read NFC tags (if available and enabled)
- **Profile suggestions**: Shows matching profiles as user types
- **Address validation**: Validates Ethereum addresses and profile accounts

### User Flow
1. User enters username, address, or scans QR/NFC
2. System searches profiles and validates address
3. User selects from suggestions or confirms entered address
4. Once valid recipient is selected, navigates to Step 2

### Key Components
- `SendToScreen` - Main screen widget
- `WalletLogic.updateAddress()` - Validates and updates address
- `ProfilesLogic.searchProfile()` - Searches for matching profiles
- `ScanLogic` - Handles QR code and NFC scanning

### Navigation
```dart
navigator.push('/wallet/${walletLogic.account}/send/$toAccount')
```

## Step 2: Amount + Description (`send_details.dart` / `tip_details.dart`)

**Routes:**
- `/wallet/:account/send/:to` - Standard send
- `/wallet/:account/send/:to/tip` - Tip flow (uses `tip_details.dart`)

**Purpose:** Enter the amount to send and optional description/message.

### Features
- **Recipient display**: Shows selected profile/address at top
- **Amount input**: Large, prominent amount field with currency symbol
- **Balance display**: Shows current balance with "MAX" button
- **Description field**: Optional multi-line text input for message
- **Validation**: Real-time validation of amount (checks balance, format)
- **Top-up option**: Shows top-up button if balance is insufficient
- **Slide to complete**: Swipe gesture to confirm and send

### User Flow
1. Displays selected recipient (profile picture, name, address)
2. User enters amount (auto-focuses on amount field)
3. System validates amount against balance in real-time
4. User optionally enters description/message
5. User swipes "Slide to Complete" button
6. System validates all fields
7. Creates `SendTransaction` object
8. Calls `walletLogic.sendTransaction()`
9. Navigates to Step 3

### Key Components
- `SendDetailsScreen` / `TipDetailsScreen` - Main screen widgets
- `WalletLogic.sendTransaction()` - Initiates transaction
- `SendTransaction` model - Contains amount, to, description
- `SlideToComplete` widget - Swipe-to-confirm interaction

### Transaction Creation
```dart
final sendTransaction = SendTransaction(
  amount: walletLogic.amountController.value.text,
  to: toAccount,
  description: walletLogic.messageController.value.text.trim(),
);

walletLogic.sendTransaction(
  sendTransaction.amount!,
  sendTransaction.to!,
  message: sendTransaction.description!,
);
```

### Navigation
```dart
navigator.push('/wallet/${walletLogic.account}/send/$toAccount/progress')
```

## Step 3: Progress / Success (`send_progress.dart`)

**Route:** `/wallet/:account/send/:to/progress`

**Purpose:** Display transaction progress and final confirmation.

### Features
- **Progress circle**: Animated circular progress indicator
- **Status messages**: 
  - "Sending..." / "Sending" (during transaction)
  - "Sent! 🎉" (on success)
  - "Failed to send" (on error)
- **Transaction details**: Shows amount, recipient, and timestamp
- **Auto-close**: Automatically closes after 5 seconds on success
- **Action buttons**: 
  - "Dismiss" button (always available)
  - "Send Tip" button (if tip feature enabled)
  - "Retry" button (on error)

### User Flow
1. Screen displays immediately after Step 2
2. Shows progress circle with 50% fill (sending state)
3. Updates to 100% when transaction is pending
4. Shows checkmark when transaction succeeds
5. Displays transaction date/time
6. Auto-closes after 5 seconds (or user can dismiss manually)
7. On error, shows retry button

### Transaction States
- `TransactionState.sending` - Transaction being processed (50% progress)
- `TransactionState.pending` - Transaction pending on blockchain (100% progress)
- `TransactionState.success` - Transaction confirmed (checkmark, auto-close)
- `TransactionState.fail` - Transaction failed (error message, retry button)

### Key Components
- `SendProgress` - Main screen widget
- `ProgressCircle` - Animated progress indicator
- `WalletState.inProgressTransaction` - Tracks transaction state
- `TransactionState` enum - Transaction status states

### State Management
The screen listens to `WalletState.inProgressTransaction` to update the UI:
```dart
final inProgressTransaction = context.select(
  (WalletState state) => state.inProgressTransaction,
);
```

## Routing Structure

All routes are nested under `/wallet/:account/`:

```
/wallet/:account/send              → Step 1: Send To
/wallet/:account/send/:to         → Step 2: Send Details
/wallet/:account/send/:to/tip     → Step 2: Tip Details (alternative)
/wallet/:account/send/:to/progress → Step 3: Progress
/wallet/:account/send/link         → Step 2: Send via Link
/wallet/:account/send/link/progress → Step 3: Link Progress
```

## State Management

### WalletLogic
- Manages transaction state and validation
- Handles address and amount controllers
- Executes `sendTransaction()` method
- Tracks `inProgressTransaction` state

### ProfilesLogic
- Manages profile search and selection
- Fetches profile data for recipients
- Handles profile suggestions

### WalletState
- `hasAddress` - Whether valid address is entered
- `hasAmount` - Whether amount is entered
- `invalidAddress` - Address validation error
- `invalidAmount` - Amount validation error
- `inProgressTransaction` - Current transaction being processed
- `inProgressTransactionError` - Transaction error state

## Models

### SendTransaction
```dart
class SendTransaction {
  String? amount;
  String? to;
  String? description;
  // For tips:
  String? tipAmount;
  String? tipTo;
  String? tipDescription;
}
```

## Special Flows

### Tip Flow
- Uses `tip_details.dart` instead of `send_details.dart`
- Route: `/wallet/:account/send/:to/tip`
- After successful send, can send additional tip
- Tip amount is separate from main transaction

### Link/Voucher Flow
- Route: `/wallet/:account/send/link`
- Creates shareable voucher/link instead of direct transfer
- Uses `SendLinkProgress` for progress tracking

### Mint Flow
- Same UI flow but mints new tokens instead of transferring
- Uses `walletLogic.mintTokens()` instead of `sendTransaction()`
- Controlled by `isMinting` flag throughout the flow

## Error Handling

- **Invalid address**: Shows error state in address field
- **Insufficient balance**: Shows "Insufficient funds" message
- **Transaction failure**: Shows error in progress screen with retry option
- **Network errors**: Handled by `WalletLogic` and displayed in progress screen

## Related Files

- `lib/screens/send/send_to.dart` - Step 1 screen
- `lib/screens/send/send_details.dart` - Step 2 screen (standard)
- `lib/screens/send/tip_details.dart` - Step 2 screen (tips)
- `lib/screens/send/send_progress.dart` - Step 3 screen
- `lib/state/wallet/logic.dart` - Transaction logic
- `lib/state/wallet/state.dart` - Wallet state management
- `lib/models/send_transaction.dart` - Transaction model
- `lib/router/router.dart` - Route definitions

