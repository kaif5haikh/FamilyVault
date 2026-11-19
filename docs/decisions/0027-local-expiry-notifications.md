# ADR 0027 Local document expiry notifications

**Status** Reminder timing and permission handling passed host tests. Android
compiled the alarm receiver and permission adapter. Physical notification
delivery and iOS compilation remain to be tested.

The operator can enable document expiry notifications in Settings. The
preference is scoped to the current vault identity in the device secure store.
An unlocked session computes the next 32 distinct future times at 9 am local
time, using the 30-day lead and the expiry date of each active document.
Past dates stay visible in the Documents screen.

Only those scheduled times and a generic reminder enter the OS notification
system. Document titles, categories and IDs stay encrypted. Android uses
inexact alarms and reloads future times after boot. iOS uses local notification
requests. The OS controls actual delivery. Sign-out and observed revocation
clear scheduled alerts. The phone can show a previously scheduled generic
alert while the vault is locked.

[Android alarm scheduling](https://developer.android.com/develop/background-work/services/alarms).
[Android notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission).
[Apple local notifications](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html).
