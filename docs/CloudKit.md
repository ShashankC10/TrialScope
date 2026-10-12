# Optional CloudKit work

Cloud sync is disabled. `TrialStore.container` accepts a CloudKit container ID, but the app currently passes none. There are no iCloud entitlements in the default target, so free Personal Team signing is sufficient for the local prototype.

To implement real sync later:

1. Use a developer team with iCloud capabilities and create a private CloudKit container.
2. Enable iCloud / CloudKit and the required remote-notification background capability in Xcode.
3. Pass that team's real container identifier to `TrialStore.container(cloudContainerID:)`.
4. Change the app's privacy/settings copy to accurately describe cloud storage.
5. Implement and test sync status, signed-out behavior, offline edits, account changes, migration, and conflicting updates on two devices.
6. Decide duplicate-record reconciliation and deletion semantics. Local read-before-insert cannot prevent simultaneous saves on two devices. Saved screens currently suppress duplicate display, and removal deletes all local records matching that ID, but this is not a complete conflict-resolution policy.
7. Review what may be stored in notes before exposing a real user-facing sync feature.

The model has defaults and no unique constraints to accommodate CloudKit-backed SwiftData. Schema compatibility alone is not validation of working synchronization. No CloudKit performance or reliability claim is made.

Apple references: [ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer), [SwiftData persistence](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches).
