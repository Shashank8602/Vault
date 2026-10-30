# Vault — Requirements Spec

Personal Android password manager. Not published to the Play Store; installed by sideloading an APK.

## 1. Platform & Stack
- **Platform:** Android only
- **Framework:** Flutter (Dart)
- **Distribution:** release APK, sideloaded onto the phone
- **Google sign-in:** used **only** to reach Google Drive for backups. It does not protect the vault and is not needed to unlock the app.

## 2. Authentication & Security
| Item | Decision |
|---|---|
| Primary unlock | Fingerprint (Android BiometricPrompt) |
| Fallback unlock | 6-digit PIN |
| Wrong PIN attempts | Escalating delays (e.g. 5 wrong → 30s, then 1m, 5m, 15m …), never wipes data |
| Auto-lock | Configurable in Settings: Immediately / 30s / 1m / 5m (default 30s) |
| Sensitive fields | Masked by default; tap the eye icon to reveal |
| Copy | Tap to copy; clipboard is cleared automatically (default 30s) |
| Screen privacy | Screenshots blocked; content hidden in the recent-apps switcher (`FLAG_SECURE`) |

**Encryption model**
- Vault data is stored in an encrypted local database (AES-256-GCM).
- The data key is wrapped by the Android Keystore and unlocked by fingerprint or PIN.
- Backups are encrypted with a separate **backup password** (Argon2id → AES-256-GCM).
- A **recovery key** (random, shown once, to be written down) can also decrypt backups if the backup password is forgotten.

## 3. Backup & Device Change
- **Google Drive auto-backup:** the encrypted `.vault` file is uploaded to the hidden Drive app-data folder. The user can turn it on or off and choose the frequency.
- **Manual encrypted file export/import:** one-tap fallback (Back up now → password → save via the share sheet). Restore: pick the file → enter the password.
- **Restore on a new phone:** on first launch, offer "Restore from backup" (from Drive or a file), then set a new PIN and fingerprint.
- Drive only ever sees encrypted data.

## 4. App Launch Flow
1. Splash screen: Vault icon/logo with a subtle animation, about 1 second
2. Fingerprint prompt appears automatically; "Use PIN" option available
3. → Home (credential list)

**First launch** (minimal, no guided onboarding): create PIN → enable fingerprint → Home.
The backup password and recovery key are set up the first time backup is enabled.

## 5. Item Types & Fields
Rule: **empty fields are hidden on the details screen.**

### Login (website / app)
- Title, Username / Email, Password 🔒, URL

### Bank & Card
- **Card:** Card number 🔒, Holder name, Expiry, CVV 🔒, Card / ATM PIN 🔒. Card network auto-detected (Visa / Mastercard / RuPay / Amex) and shown as a styled card visual.
- **Account:** Account number 🔒, IFSC, Branch, UPI ID, UPI PIN 🔒

### Identity documents (template per document)
- **Aadhaar:** number 🔒, name, DOB, linked phone
- **PAN:** number, name, DOB
- **Passport:** number, issue date, expiry date, place of issue
- **Driving License:** number, validity, issuing authority
- **Voter ID:** number, name

🔒 = masked by default

## 6. Screens

### Home (Vault)
- Greeting with the user's name
- Search bar (by title, username, URL)
- Single filter button ("All ▾") next to search: opens a sheet of categories with counts
  - **Inline management:** pencil → rename / recolor / delete; "New category" adds one
  - Default categories are fully editable (e.g. rename "Social Banking" → "Banking")
- Item list: letter avatar, title, subtitle (username or masked card ending `•••• 4821`)

### Add item
- Center "+" in the floating nav → bottom sheet: **Login / Bank & Card / Identity**
- Each type opens its own form; category picker
- No generator or strength helpers (out of scope)

### Item details
- Fields as defined above, with empty fields hidden
- Mask / reveal and copy with clipboard auto-clear
- **Edit** and **Delete** (delete asks for confirmation)

### Profile
- Name and avatar (photo or initials)
- Vault stats: total items, count per category, last backup date
- Linked Google Drive account (connect / disconnect)

### Settings
- **Security:** fingerprint toggle, change PIN, change backup password, view recovery key (requires authentication), auto-lock timer, clipboard clear time
- **Backup & restore:** Drive auto-backup toggle and frequency, Back up now, Export file, Import / Restore
- **Appearance:** Theme (System / Dark / Light), optional real blur for the nav bar

## 7. Design Direction
- **Style:** clean, minimal and technical, like a security tool rather than a lifestyle or fashion app
- **Palette:** flat gold accent on obsidian (dark). The light theme uses warm off-white surfaces with a deeper gold. **No decorative gradients or glows.**
- **Fonts:** IBM Plex Sans for the interface; IBM Plex Mono for secrets, card numbers, PIN digits and small uppercase labels
- **Shapes:** tight corner radii (8–16px) on cards, fields and chips; the floating nav bar stays pill-shaped
- **Theme:** dark and light, following the system by default
- **Performance:** no live blur in lists. Depth comes from layered surfaces and hairline borders. The nav bar is always frosted (blurred translucent fill); there is no toggle.
- **Navigation:** floating pill-shaped bottom nav, iOS style: Vault · (+) · Profile · Settings
- **Motion:** smooth page transitions, hero animation from a list item to its details, a subtle splash animation
- **Branding:** app name **Vault**, with a custom shield/vault icon and splash (to be designed)

## 8. Out of Scope (for now)
- Password generator, strength or reuse warnings
- Website favicon fetching (letter avatars instead)
- Android Autofill service
- Secure notes, net-banking login fields
- Document photos
- TOTP / 2FA codes
- Favorites, sort options
- Guided onboarding, "Erase all data" option
- iOS

## 9. Decisions made during build (2026-10-30)
- **Forgot PIN:** unlock with the recovery key, then set a new PIN.
- **Deleting a category:** its items move to "Uncategorised" (nothing is deleted).
- **Revealed fields:** hide again after 30 seconds.
- **Recovery key:** created at first launch (not at first backup), because forgot-PIN needs it. Stored inside the encrypted vault so Settings can show it again after PIN/fingerprint.
- **Backups:** `.vault` file holds the vault ciphertext plus the data key wrapped by the backup password and by the recovery key. It never holds the PIN.
- **Release signing key:** a `.jks` file kept outside the project, referenced by `android/key.properties` (back it up; losing it breaks update-in-place and Drive sign-in).
- **Not built yet:** Google Drive auto-backup and Drive account on Profile.
- **Header:** a "Lock now" button replaces the avatar; in-app restore keeps the current PIN, fingerprint and recovery key.
