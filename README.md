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
- Share properties, gold and other asset records with family members. I tested changes to ownership, value and rent between two accounts on my computer.
- Share loans and repayments with family members. Corrections keep the old entries and show the updated amount due.
- Keep PDFs, photos and scans in the encrypted vault on your device. You can search by title, keep old versions and link a file to a transaction or asset.
- Share encrypted documents with approved family devices. Add a file without internet and the app will share it when it can connect again. I tested this with sample files on a local Supabase server.
- Edit shared document details, archive files and bring them back with their old versions.
- Link a shared document to a family transaction or asset. If two people add a new version at the same time, you can keep your saved copy and share it as the next version.
- Create an encrypted backup and save a copy in Files. On a fresh install, use the backup file and your separate recovery key. I tested this with sample records on my computer.
- Save encrypted backups to Google Drive and choose an older copy to restore. This needs Google Drive setup for your build. I tested the upload and restore with a local test server.
- Set daily or weekly backups that run while the vault is open. You can also copy them to the Google account you choose.

## What I am still building

I am working on shared sync for business records.

## Run it

Install Flutter and set up an Android emulator or connect an Android phone. From the project folder run these commands.

```bash
flutter pub get --enforce-lockfile
flutter run
```

Set a screen lock on the device before creating a vault. The local app works without a Supabase account. For the tool versions and checks, see the [setup guide](docs/development.md).

The Android debug build has been tested. The iOS project is included and needs a Mac with Xcode for build testing. Please use sample data while the app is in development.

See the [project status](docs/development/IMPLEMENTATION_STATUS.md) for what has been tested so far.
