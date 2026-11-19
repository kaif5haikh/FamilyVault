# ADR 0025 Link shared documents to family holdings

**Status** Implemented and exercised with the local Auth, Storage and Data
API provider fixture on 2026-11-19.

Each linked document refers to one posted transaction or one family asset.
Use the same document revision and explicit link and unlink operations for
both targets. A composite foreign key establishes family scope. Before
creating an asset link, verify that the target is an active family holding and
that the enrolled device has a key grant for the latest document version.
Keep link removals as immutable tombstones.

Finance receipts travel before document changes on the device. An asset
created offline can be queued together with a link. Document link replay waits
if the associated asset is missing in the receiving cache. Each server link
receipt binds the operation, document, version, revision and chosen target.

The new list endpoint includes asset links for clients that understand both
target types. The existing transaction endpoint and journal-only listing keep
their prior shape. Drift v6 already has both columns. An encrypted recovery
copy keeps its existing links when installed as a detached local vault.
