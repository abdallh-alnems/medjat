# App Store — App Review Information (Permedjat)

Paste the block below into **App Store Connect → App version → App Review Information → Notes**,
and upload `review_demo_join_qr.png` as the attachment.

---

## Demo account (permanent — never expires)

The app can be accessed in two ways. Either is sufficient.

### Option A — Sign in with phone + activation code
- Phone number: **+201000000000**  (you may also type it locally as 01000000000)
- Activation code: **PERMEDJAT2026**

### Option B — "Scan Join QR" feature
On the join screen tap **Scan Join QR** and scan the attached QR image
(`review_demo_join_qr.png`). It signs straight into the same demo employee.
The attached QR encodes:
`https://permedjatapp.com/join?token=1413c55ff3123e4d00ced52db278c2db96b54fd9c5b3029c8d4c6e6fd611b93a`

Both credentials are permanent demo logins: they never consume an activation
code and never expire, so they remain valid for every future review.

---

## Notes on the permission prompts (Guideline 4)
All permission usage descriptions are now localized via `InfoPlist.strings`
(English + Arabic) so the text always matches the device language.

- Camera: used to scan the join QR and photograph required documents.
- Location: used to verify the branch location and GPS check-in radius.
- Photos: used to attach / save required documents.
