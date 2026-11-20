# FamilyVault usability audit

Baseline reviewed on 19 November 2026 at `6b5d93c`. The USB-authorized Moto
G34 ran the existing signed build 3. ADB reached its device verification
screen with the “Unlock vault” action. The previous device report and its
masked dashboard and preview captures document the authenticated baseline.
The tables below record a source and navigation review. New interaction and
rendered evidence belongs in the implementation checklist and device report.

| Screen or flow | Baseline finding | Change to verify |
| --- | --- | --- |
| Welcome, first setup, device unlock | Welcome explains the product in general terms. The setup button, two names and phone verification appear in separate views, with no short introduction or saved tour. | Give a short optional tour, a prominent way to start and plain phone verification instructions. |
| Existing family sign-in, invite and phone approval | “Fingerprint,” “enrollment” and different access actions appear together. A member should know whether they need to sign in, accept an invitation or wait. | Keep the approval code and secure checks. Explain what to compare and who can approve. |
| Home | Five large cards, business summary, trend chart and activity compete for space. The first action opens a generic entry form. | One money summary and direct received, spent and move actions. Keep reports and business detail reachable. |
| Tab bar, More, wide navigation | Money activity and accounts have separate tabs. Documents and family tools are hard to find. The old layout rebuilds the workspace wrapper on each route. | Five clearly named areas with one navigation shell and remembered tab positions. |
| Money activity, details and correction dialog | List paints all matching rows, shows stored entry types and omits account names. Corrections use accounting phrases. | Give each entry an everyday label and account context, build rows as needed, and explain the retained original before undoing or correcting. |
| Received, spent, move and correction forms | Common entries use the same Type dropdown and require a description. Long spacing and currency validation invite extra work. | Open the right form directly, explain the amount/accounts, keep dates and optional notes, and preserve exact paise and one posting per save. |
| Cash, bank, categories, account details and statement check | Account cards expose raw kinds and INR codes. “Reconcile” is unclear. | Give account types familiar names and explain that the user compares the statement total with this app. |
| Spending plans and reports | “Budget,” “net worth” and charts require interpretation. Charts are useful at a deliberate report destination. | Use spending limits and predictable monthly/yearly explanations. Keep exact amounts and existing report definitions. |
| Ownership list, item editor and item details | “Asset,” “holding,” “valuation” and ownership math dominate the form. Property, gold, vehicles and investments share one long editor. | Use What we own, direct add routes by item type, simpler value labels and optional detail grouping. |
| Ownership actions, value history, rent and close | Forms use internal terms such as book value and disposal. The date and effect on records matter. | Explain estimated value, money received from rent and what closing an item changes in its history. |
| Loans list, record, repayments and estimates | “Principal,” “settlement” and lender/borrower directions are easy to confuse. Amount left and terms compete. | Show what the family owes separately from money lent to others, and explain loan amount, interest and payment history. |
| Business list, details, stock and pay | Revenue, costs, inventory statistics, workers and edit actions stack up on one route. | Keep the actual records and cost formulas. Use readable section headings, smaller summary cards and familiar terms. |
| Document list and Add sheet | A useful search and category filter are hidden behind More. Add has a short label, and cloud status contains implementation language. | Make Documents a tab and label file or camera choices. Keep exact source category and pending state. |
| Document name, owner, version, preview and export | An explanatory owner label is missing. Version and archive actions are functional, but sharing, local saves and export can be confused. | Explain whose papers they are, who can open them, how copies are saved, and when a file is ready. Preserve all access checks. |
| Family members, invitations, device list and administrator dialogs | Member management is found during sign-in. The screen can show raw role/status strings and an advanced device identifier by default. | Give family a tab with names and roles. Keep signed administrator checks and move advanced identifiers below the main instructions. |
| Settings, privacy, theme, language and reminders | Several tall cards combine multiple purposes. Existing locale choices are English and Hindi. | Group by appearance, safe copies and privacy. Offer conversational Hindi alongside default English. |
| Safe copies, Google Drive and recovery | “Backup,” “recovery,” “verified copy” and detailed schedule messages appear together. | Show how to make and keep a protected copy, when it is ready, and what file and key are needed to bring records back. Preserve separate receipts. |
| Update problems, about and errors | Internal terms recur in user messages. Protected operations already return curated failures. | Use plain status and retry text. Keep technical IDs, history or licence details available where they serve a real purpose. |

The review covers the routed screens and their dialogs, selection sheets and
shared components. It does not substitute for testing the recalculated numbers,
permission gates, offline transitions, copy verification or rendered layouts.
