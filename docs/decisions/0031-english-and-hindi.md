# ADR 0031. English and Hindi on the phone

Accepted 20 November 2026. The owner selected English by default and
conversational Hindi in Devanagari. This updates the language choice in
[ADR 0030](0030-family-ux-navigation.md).

Use the same language picker on the welcome screen and in Settings. Remember
the choice in existing device secure storage and read it before the vault
opens. A compatible earlier vault preference is a fallback. Earlier Marathi
choices fall back to English, and the Marathi catalogs and stored data are
preserved. Finance operations keep integer paise and document access retains
its existing verification.

Translate the interface and seeded categories. Keep user-entered names,
notes, filenames, and other stored record text. Error messages use reviewed
Hindi copy and a plain fallback for an unexpected service result. The device
receives only reminder times and the selected English or Hindi language
code. The notification body stays generic.

[Language and copy audit](../UIUX/hindi-copy-audit.md).
