# ADR 0030. Organize the workspace around family tasks

Accepted 20 November 2026.

The owner updated the language choices in [ADR 0031](0031-english-and-hindi.md).

Use one GoRouter stateful shell for Home, Money, Documents, Family and More.
Give account lists, records and tools their own Back navigation. Keep the
existing authenticated route guard and lifecycle lock. Home gives priority to
cash and bank money, the current month and quick entry. Reports still uses
the existing reporting data and dates.

Open an income, spending or move form with its kind selected. Use a category
name as the recorded description when an optional note is empty. A move uses
the action name. Ledger validation, operation IDs, audit facts, paise and
correction behavior stay in their existing write path.

Keep one offline topic catalog and one reusable step view for help and the
first tour. Guide links open existing workflows. Persist only the tour
completion and phone language hint through the existing secure store. Retain
the theme and language preferences in the opened vault. Add Marathi to
English and Hindi for the common tasks and guidance.

No Drift migration, data conversion or hosted settings change is needed for
this design. The physical device report carries separate evidence for host
layouts, signed artifacts and handset behavior.

[Design system](../UIUX/design-system.md).
[Usability audit](../UIUX/ux-audit.md).
