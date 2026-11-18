# FamilyVault

FamilyVault is a Flutter app I am building to help a family keep track of money and important documents in one place. It uses rupees and Indian number formatting, including lakh and crore.

## What works now

- Add cash and bank accounts, income, expenses and transfers.
- Set monthly budgets and see where the money goes.
- Record property, gold, silver and other assets with ownership details and a history of their values.
- Record loans and repayments. See principal, interest paid and the amount still due.
- Correct a transaction while keeping the original entry in its history.
- Save records on the device without internet. The app encrypts the local database and uses your device lock to open it.

## What I am still building

I am working on business accounts, family login, sync between devices and the document vault. Encrypted backups for the device and Google Drive are also part of the project.

## Run it

Install Flutter and set up an Android emulator or connect an Android phone. From the project folder run these commands.

```bash
flutter pub get --enforce-lockfile
flutter run
```

Set a screen lock on the device before creating a vault. The local app works without a Supabase account. For the tool versions and checks, see the [setup guide](docs/development.md).

The Android debug build has been tested. The iOS project is included and needs a Mac with Xcode for build testing. Please use sample data while the app is in development.

See the [project status](docs/development/IMPLEMENTATION_STATUS.md) for what has been tested so far.
