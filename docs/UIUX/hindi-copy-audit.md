# English and Hindi copy audit

English is the default. हिंदी (भारत) selects conversational Hindi in
Devanagari. Choose a language from the welcome screen or from More,
then Settings. The phone remembers this choice.

| Area | App copy reviewed |
| --- | --- |
| Welcome and navigation | Setup, device unlock, tour, tab names, settings and app help |
| Money and reports | Received, spent and moved money, account fields, budgets, chart labels, corrections, INR units and validation |
| What we own and owe | Property, gold, shares, prices, loans, repayments, estimates and confirmation dialogs |
| Business | Sales, costs, stock, workers, history and profit |
| Documents and safe copies | File choices, categories, expiry, versions, sharing, restore, Drive and the generic reminder |
| Family management | Sign-in, invitations, phone approval, access changes, updates and safe errors |

The source review checked both fixed labels and messages assembled with
dates, amounts or names. Use `VaultStrings.text` for shared keys and guide
steps. Use `context.tr` for feature copy and `VaultStrings.failure` for
safe service failures. A new label or help topic needs English and Hindi
copy. Give placeholders names, then supply their values separately.

The audit found matching English and Hindi entries for all 151 shared
keys and all 56 tour and help keys. It checked 816 additional feature and
service messages and found a catalog entry for each direct translation
key in the interface. Verified the 320-point Hindi form and the Hindi
tour in host renders using a Devanagari system font.

App and provider names, file format names, numbers, account and document
names typed by the family, notes, and technical identifiers keep their
original form. System controls and external file, sign-in and device
verification sheets follow their platform or provider language settings.
The native iOS permission descriptions include Hindi for a Hindi system
locale. iOS native UI needs verification on Apple hardware.

The previous Marathi translation source is preserved. The shipped picker
shows English and Hindi.

[Language decision](../decisions/0031-english-and-hindi.md).
[Android evidence](../testing/android-physical-device-validation.md).
