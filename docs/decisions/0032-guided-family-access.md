# ADR 0032. Guided family access

Accepted on 20 November 2026 as a presentation update to the existing family
access rules. Family name and people come from the enrolled workspace. A
local vault shows its own name and the person using it. A shared family
administrator gets a direct invitation form and a separate screen for
pending invitations, people and phones.

The form prepares an invitation for an individual account. It explains the
next step after the server acknowledges the request. Signing in still uses
the member's own email and password. From a configured welcome screen,
the invitation path opens family sign-in directly. An invited person reviews
the family and shared access, explicitly accepts, and then sets up the phone
for administrator approval. The option to wait keeps the invitation available.

Migration `202611200001_invitation_review.sql` adds the inviter's display
name to the existing response for the authenticated invited email. The app
accepts older responses with no inviter name. The verified email, expiry,
device key proof and administrator authorization rules continue to apply.
The server still grants shared finance and document access only to an
authorized member on an approved phone.

This flow relies on the existing account provisioning and Supabase setup.
After saving, the administrator can tell the invited person which email to
use. The existing invitation state and enrollment protocol remain authoritative.

[Usability review](../UIUX/family-onboarding-audit.md).
