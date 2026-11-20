# FamilyVault design system

FamilyVault uses a warm off-white surface and a deep green accent. Green
marks a primary action or selection. A pale green summary holds the main
number on Home. A dark palette uses the same hierarchy. Words and icons
carry status in both themes.

| Element | Use |
| --- | --- |
| Type | A clear title and a short explanation when context is needed. Values have stronger weight and tabular figures where useful. |
| Spacing | Reuse the 16-point page gutter, 12-point gap and 20-point section spacing in `VaultTheme`. |
| Actions | Use a filled action to add or save, an outlined action to navigate or take a common shortcut, and a text action for secondary choices. Button targets start at 48 logical pixels. |
| Cards | Use one quiet card for a summary, result or action. `VaultLink` pairs a label with a familiar icon and a flexible text area. |
| Status | Use `EmptyNotice` for a next step, `FailureNotice` for a readable error, and a spoken save notice for completed local writes. |
| Forms | Put essential fields first. Give optional fields plain labels. Keep advanced values available on the same screen when a person needs them. |
| Navigation | Use labelled tabs. Use a wider left column on tablets and wrapped text controls at enlarged Android text sizes. Preserve the system Back button for detail screens. |

Use the shared locale catalog for reused text. Let fields and card text grow
vertically. Test narrow layouts at 320 logical pixels and 200% text, and let
a person scroll when large text needs more room. Home uses compact Indian
rupee notation. Detailed records retain exact paise.

Home's amount control also hides recent money activity. A screenshot at the
platform level remains subject to the existing Android protection. Capture
rendering evidence with a synthetic test fixture.

[Navigation and onboarding](navigation-and-onboarding.md).
[Plain-language guide](plain-language-guide.md).
