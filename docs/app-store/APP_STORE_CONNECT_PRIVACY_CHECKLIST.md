# App Store Connect privacy checklist — FastCat iOS (US)

Use this checklist only after all items in `US_PRIVACY_DATA_INVENTORY.md` have been confirmed by the operator.

## App Privacy

1. Select **Yes, we collect data from this app**.
2. For each declared type, select **Linked to the user's identity** where it is associated with an account or support session.
3. Select **Used for Tracking: No** unless a processor uses data to track the user across apps or websites owned by other companies for advertising or measurement.

### Candidate data types to evaluate

| App Store Connect type | Candidate purpose | Submit as declared? |
| --- | --- | --- |
| Contact Info > Email Address | Account Management, App Functionality | Yes, based on login and Crisp support integration |
| Identifiers > User ID | Account Management, App Functionality | Yes, based on account/session handling |
| Identifiers > Device ID | App Functionality, Fraud Prevention/Security | Yes, based on the generated device ID used for device management |
| Purchases > Purchase History | App Functionality | Confirm with backend; likely yes for plan/order history |
| Financial Info > Other Financial Info | App Functionality | Confirm whether balances/commission data are retained and classify accurately |
| User Content > Customer Support / Other User Content | App Functionality | Confirm Crisp message and attachment retention |
| Photos or Videos | App Functionality | Declare if support attachments are stored outside the device |
| Location > Coarse Location | App Functionality, Analytics | Declare only if IP-derived region is retained or used beyond a real-time support request |
| Diagnostics > Other Diagnostic Data | App Functionality | Confirm diagnostic uploads and server retention |

Do **not** declare payment card or payment account information when it is entered solely on the external payment provider's website and is never received or retained by FastCat.

## URLs and customer-facing materials

- **Privacy Policy URL:** publish the finalized policy at `https://www.fastcat6.com/privacy` (or inject `FASTCAT_PRIVACY_POLICY_URL` at build time).
- **Terms of Service URL:** publish the finalized terms at `https://www.fastcat6.com/terms` (or inject `FASTCAT_TERMS_OF_SERVICE_URL` at build time).
- **User Privacy Choices URL:** publish a page that describes account deletion and the privacy contact channel; it may link to the in-app Account Information page instructions.
- **Support URL:** an HTTPS support page or support contact landing page.
- Make sure the App Store Connect privacy policy URL, the in-app Data & Privacy notice, and the public policy have the same effective date and data practices.

## Submission notes to prepare

- State that FastCat uses a Packet Tunnel VPN extension and explain the first-connect system authorization flow.
- Provide a working review account and a usable test node.
- Explain that payments, if shown, open an external browser and that the app refreshes order status from the FastCat API.
- Identify the exact checkout and support domains used in the submitted build.

## Required operator sign-off

- [ ] Legal entity/contact details inserted in the public policy.
- [ ] Retention periods confirmed for account, order, support, IP/network, and diagnostic data.
- [ ] Crisp data processing settings and privacy terms reviewed.
- [ ] Payment provider and checkout-domain processing reviewed.
- [ ] No advertising/analytics tracker is enabled, or any enabled tracker is declared.
- [ ] Final policy is publicly reachable over HTTPS before App Store Connect submission.
- [ ] Both legal URLs return HTTP 200 without login, bot challenge, region block, or redirect to the home page.
