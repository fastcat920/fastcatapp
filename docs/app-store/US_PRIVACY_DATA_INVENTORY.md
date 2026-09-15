# FastCat iOS privacy data inventory

Last reviewed: 2026-09-04

This inventory is based on the client source code. Before publishing the App Store privacy label, confirm the retention and onward-sharing columns with the service operator and each processor.

| Data | Source and recipient | Purpose | App Store Connect assessment |
| --- | --- | --- | --- |
| Email address | Login, registration, password reset; FastCat API; Crisp when support is opened | Account authentication and customer support | Contact Info > Email Address; linked to identity |
| Account/session identifier | Auth token and FastCat API | Authenticate requests and maintain the account session | Identifiers > User ID; linked to identity |
| Random app device ID, device name, OS/app version | `device_identity_service.dart`; FastCat API at login | Device/session management and concurrent-device control | Identifiers > User ID and Diagnostics > Other Diagnostic Data; linked to identity |
| Subscription, plan, traffic, balance and order status | FastCat API; Crisp support session data | Deliver the service, answer support requests | Purchases and Financial Info > Other Financial Info; linked to identity. Confirm the precise backend schema before submission. |
| IP address, approximate region and ISP | FastCat API and support helper; Crisp session data when support is opened | Network service operation and support diagnostics | Location > Coarse Location and Identifiers/Diagnostics as applicable; disclose if retained or used beyond the real-time request. |
| Support messages and image attachments | User action; Crisp; ticket image upload path exists separately | Customer support | User Content > Other User Content and Photos or Videos; linked to identity if retained. |
| VPN connection/request information | Packet Tunnel and FastCat service infrastructure | Provide VPN connectivity, security and troubleshooting | Confirm whether server logs are retained. If retained, disclose the applicable data type and purpose. |
| Payment credentials | External payment website only | External checkout | Do not declare card credentials if FastCat never receives or retains them. Orders and purchase records still require disclosure. |

## Tracking

No advertising SDK or cross-app advertising identifier use was found in the client source. The proposed answer is **No, data is not used for tracking**, subject to confirmation that the API, Crisp configuration, payment provider, and any future analytics tools do not use it for cross-app or cross-site tracking.

## Third parties found in the client

- Crisp online support: receives email, nickname, client/subscription session data, and user-submitted support content when opened.
- External payment provider: receives checkout data in the external browser; exact provider and data are controlled by the checkout implementation.
- Image picker: accesses the camera/photo library only after the user chooses to send an image.

## iOS privacy manifest

`ios/Runner/PrivacyInfo.xcprivacy` conservatively declares email address, user
and device identifiers, purchase history, other financial information, customer
support content, user-selected photos, coarse location, other usage data, and
other diagnostic data. All are marked as linked to the account, used only for
app functionality, and not used for tracking. UserDefaults access is declared
with required-reason code `CA92.1`.

The iOS dependency lock was regenerated on 2026-09-04. Google ML Kit and the
unused mobile-scanner dependency are no longer included in the iOS Pods.

## Operator confirmations required before submission

1. Legal entity name, postal address, privacy contact email, and effective date.
2. API, VPN, order, device, and support-log retention periods.
3. Whether IP address, ISP, region, connection metadata, or diagnostics are retained after the request.
4. Current Crisp data processing agreement, workspace region, retention configuration, and any enabled analytics/tracking.
5. Payment provider name, checkout domains, and whether FastCat receives any payment credential.
