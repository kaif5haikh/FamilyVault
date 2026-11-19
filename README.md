# FamilyVault

FamilyVault is my Flutter project for keeping family money records and important documents in one place. It uses rupees and shows amounts in lakh and crore.

## What works now

- Add income, expenses, transfers and bank accounts. Set a monthly budget and see how much you saved.
- Track property, gold, silver, other assets and loans. See old values and payments.
- Track business income, costs, stock, worker payments and profit.
- Correct a transaction and keep the original entry in its history.
- Save records without internet. The app encrypts the local database and opens it with your device lock.
- Use separate family accounts to share records between approved phones.
- Store PDFs, photos and scans in an encrypted vault. Search by title, keep old versions, add expiry dates and link files to records.
- Create an encrypted backup and save it to Files or Google Drive. Keep the recovery key separately. Daily or weekly backups can run while the vault is open.

## Run it

Install Flutter and set up an Android emulator or connect an Android phone. From the project folder run these commands.

```bash
flutter pub get --enforce-lockfile
flutter run
```

Set a screen lock before creating a vault. The local app works without a Supabase account. Family sync and Google Drive need their own setup. [Installation guide](docs/installation.md).

## Testing

I tested family sync and backup restore with sample data on my computer. I also built and checked a signed Android APK and App Bundle. Phone testing is still pending. The iOS project needs a Mac with Xcode for build testing. [Project status](docs/development/IMPLEMENTATION_STATUS.md).
