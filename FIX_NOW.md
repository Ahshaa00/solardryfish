# 🚨 FIX REGISTRATION - 2 STEPS

## Problem
Registration fails at saving user profile to Realtime Database.

Error: `Permission denied at /userIdIndex/USR-251024-RSHK`

## ✅ SOLUTION

### Step 1: Deploy Firestore Rules

1. Open: https://console.firebase.google.com
2. Go to: **Firestore Database** → **Rules**
3. Copy ALL from: `firestore.rules.test`
4. Paste and click **Publish**

### Step 2: Deploy Realtime Database Rules

1. In Firebase Console, go to: **Realtime Database** → **Rules**
2. Copy this:

```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```

3. Paste and click **Publish**

### Step 3: Test

```bash
flutter clean
flutter run
```

Try registration with NEW email. Should work! ✅

---

**Note:** These are test rules (very permissive). Fix later with proper rules from `database.rules.json` after adding `userIdIndex` section.
