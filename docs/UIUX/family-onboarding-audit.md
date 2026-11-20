# Family onboarding and everyday use

Reviewed at `fe8ae55` against the exact signed Android build 5 and the source
behind each route. The earlier audit covers the full screen inventory.
[Screen inventory](ux-audit.md).

| Priority and screens | Friction to address |
| --- | --- |
| First use, language and access | Keep the short optional tour and saved language. Give people with a family invitation a direct sign-in path on a configured build. Explain which account to use. |
| Family and permissions | Show the actual family name, members, roles and their access. The main add action should be easy for the administrator to find. Keep private invitation details inside the verified controls. |
| Create invitation | Explain that the invited person signs in with their own prepared account. Save an invitation only after verification. Give a clear next step once the server confirms it. |
| Review and join | An invitation row currently accepts on tap. Show the family, inviter when available, shared access and phone approval first. Require an explicit choice to join. |
| Invitations and phones | Group pending invitations and registered phones on a separate page. The server calls an approved phone enrolled. Show a familiar status and which person uses it. |
| Home, Money, incoming, outgoing and transfer | Keep the daily shortcuts and separate exact-paise forms. Help belongs close to the controls. Leave the correction and original record visible in money history. |
| Accounts, ownership, debt and reports | Keep accounts, details, repayments, estimates and reports off the main overview. Offer guidance where users may need help adding their first record. |
| Documents, details and versions | Keep search, file or camera import, ownership, dates, past versions, and authenticated preview. Offer help from the document list. |
| Safe copies and recovery | Keep download, verified archive, separate key and restore checks. Explain what a person needs before starting. |
| Help, More, Settings and messages | Keep the five destinations and offline search. Make family relationships easy to find as search words. Keep English first and Hindi selectable. Use concise status and plain-language permission explanations. |

The source, tracked files and Git subjects were checked for changes from
the accidental request. There was no implementation to remove.

## Checklist

- [x] Inspect handset and preserve exact signed APK and bundle for build 5.
- [x] Verify upgraded handset APK bytes and measure the first launch.
- [x] Audit routed surfaces and existing translations.
- [x] Verify build 5 interactions and document the physical limits.
- [x] Implement and test invitation, joining, and phone approval improvements.
- [x] Refine welcome and contextual guidance on the real routes.
- [x] Run host, local service and binary regression checks.
- [x] Install and launch the exact signed build 6 APK on the Moto G34.
- [x] Open build 6 protected records on the phone and check the new Family screen.
- [x] Verify cleanup and prepare the code and validation record for publication.

The remaining environment check is a hosted family invite and join on a
configured handset. The signed USB tests used the local synthetic vault.
[Physical Android validation](../testing/android-physical-device-validation.md#2026-11-20-signed-build-6-with-guided-family-access).
