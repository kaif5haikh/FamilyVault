# FamilyVault

FamilyVault is a Flutter app I am building to help a family keep track of money and important documents in one place. It uses rupees and Indian number formatting, including lakh and crore.

## What works now

- Add cash and bank accounts, income, expenses and transfers.
- Set monthly budgets and see where the money goes.
- Record property, gold, silver and other assets with ownership details and a history of their values.
- Record loans and repayments. See principal, interest paid and the amount still due.
- Track business income, expenses, stock, worker payments and profit.
- Correct a transaction while keeping the original entry in its history.
- Save records on the device without internet. The app encrypts the local database and uses your device lock to open it.
- Sign in with a family account and sync accounts, transactions, budgets and bank statement checks. I tested this with two test accounts using Supabase on my computer.
- Keep PDFs, photos and scans in the encrypted vault on your device. You can search by title, keep old versions and link a file to a transaction or asset.
- Share encrypted documents with approved family devices. Add a file without internet and the app will share it when it can connect again. I tested this with sample files on a local Supabase server.

## What I am still building

I am working on shared sync for assets, loans and business records. Editing document details across devices and encrypted backups for the device and Google Drive are also in progress.

## Run it

Install Flutter and set up an Android emulator or connect an Android phone. From the project folder run these commands.

```bash
flutter pub get --enforce-lockfile
flutter run
```

Set a screen lock on the device before creating a vault. The local app works without a Supabase account. For the tool versions and checks, see the [setup guide](docs/development.md).

The Android debug build has been tested. The iOS project is included and needs a Mac with Xcode for build testing. Please use sample data while the app is in development.

See the [project status](docs/development/IMPLEMENTATION_STATUS.md) for what has been tested so far.
