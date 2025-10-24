# 🔧 REBUILD APP TO APPLY FIXES

## ⚠️ **IMPORTANT: YOU MUST REBUILD THE APP!**

The code changes I made **will NOT take effect** until you rebuild the app. The app running on your phone is still using the old 30-second timeout.

---

## 🚀 **HOW TO REBUILD:**

### **Option 1: Hot Restart (Quick - 10 seconds)**
1. In VS Code, press `Ctrl + Shift + P`
2. Type "Flutter: Hot Restart"
3. Press Enter

**OR**

1. In the terminal where Flutter is running
2. Press `R` (capital R for full restart)

---

### **Option 2: Full Rebuild (Recommended - 2 minutes)**

**Step 1: Stop the app**
- Press `Ctrl + C` in terminal
- Or click Stop button in VS Code

**Step 2: Clean build**
```bash
flutter clean
```

**Step 3: Get dependencies**
```bash
flutter pub get
```

**Step 4: Rebuild and run**
```bash
flutter run
```

---

## ✅ **VERIFICATION AFTER REBUILD**

### **1. Check Debug Console**
Look for these messages:
```
🔍 Dashboard: Last update X.Xs ago | Online: true | Stale: false
```

The "Stale:" check should now use 60000 instead of 30000.

### **2. Test Monitor Page**
- Open System Monitor
- Should show sensor data (not "System Offline")
- Should show "Status: Working" or actual sensor values

### **3. Test Dashboard**
- Should show "Online" badge
- Should show temperature and humidity
- Should match Monitor page status

---

## 🐛 **IF STILL SHOWING OFFLINE AFTER REBUILD**

### **Check 1: Is ESP32 Actually Uploading?**

Open Firebase Console:
1. Go to Realtime Database
2. Navigate to: `/hardwareSystems/SDF202509AA/status/lastUpdate`
3. Watch if the number changes every 5 seconds
4. If NOT changing → ESP32 problem

### **Check 2: What's the Actual Time Difference?**

Add this debug code temporarily:

**In `system_monitor_page.dart` line ~221:**
```dart
final now = DateTime.now().millisecondsSinceEpoch;
final difference = now - lastUpdateTimestamp;

print('🔍 Monitor: Last update ${(difference / 1000).toStringAsFixed(1)}s ago');
print('🔍 Monitor: Online=$online | Stale=${difference > 60000}');

final stale = difference > 60000;
```

Then check the debug console to see actual timing.

---

## 🎯 **EXPECTED BEHAVIOR AFTER REBUILD**

### **Scenario 1: Normal Operation**
```
ESP32 uploads every 5 seconds
App receives updates
Dashboard: ✅ Online
Monitor: ✅ Shows sensors
```

### **Scenario 2: Network Delay (30-50 seconds)**
```
ESP32 can't reach Firebase temporarily
OLD behavior: ❌ Goes offline after 30s
NEW behavior: ✅ Stays online (waits 60s)
```

### **Scenario 3: Actual Offline (>60 seconds)**
```
ESP32 disconnected for 60+ seconds
Dashboard: ❌ Offline
Monitor: ❌ System Offline
```

---

## 📱 **CURRENT ISSUE IN YOUR SCREENSHOTS**

### **Image 1: Homepage**
- Shows "Online" badge (green) ✅
- Shows sensor data ✅
- Temperature: 30.9°C ✅

### **Image 2: Monitor Page**
- Shows "Status: Unknown" ❌
- Shows "Sensor not connected or no valid data" ❌
- All 4 sensors showing error ❌

**Why:**
- App is still using OLD code (30s timeout)
- System went offline due to short timeout
- Homepage shows "Online" from Firebase `status/online` field
- Monitor checks local `online` variable (set by timeout logic)
- **You need to rebuild to apply the 60s timeout fix!**

---

## 🔧 **QUICK FIX STEPS**

1. **Stop the app** (Ctrl+C)
2. **Run:** `flutter clean`
3. **Run:** `flutter pub get`
4. **Run:** `flutter run`
5. **Wait** for app to install on phone
6. **Test** Monitor page again

**The sensors should now show data instead of "System Offline"!**

---

## 📊 **FILES THAT WERE CHANGED**

These files now use 60-second timeout instead of 30:

1. ✅ `lib/screens/dashboard_screen.dart` (line 297)
2. ✅ `lib/pages/system_monitor_page.dart` (line 225)
3. ✅ `lib/screens/schedule_screen.dart` (line 152)
4. ✅ `lib/pages/system_selector_page.dart` (line 130)
5. ✅ `lib/pages/homepage.dart` (line 85)

**All changes are saved, but app must be rebuilt!**

---

## ⚡ **ALTERNATIVE: INCREASE ESP32 UPLOAD FREQUENCY**

If you want even more stability, also change ESP32:

**File:** `c:\Users\User\Downloads\ESP32_3\ESP32_3.ino`

**Line 34, change:**
```cpp
// OLD:
#define FIREBASE_UPLOAD_INTERVAL 5000

// NEW:
#define FIREBASE_UPLOAD_INTERVAL 3000  // Upload every 3 seconds
```

Then upload to ESP32.

**Result:**
- ESP32 uploads every 3 seconds
- App waits 60 seconds
- Can miss 20 uploads before offline
- Super stable! ✅

---

## ✅ **SUMMARY**

**Problem:** App still using old 30-second timeout code

**Solution:** Rebuild the app to apply 60-second timeout

**Steps:**
1. Stop app
2. `flutter clean`
3. `flutter pub get`
4. `flutter run`
5. Test again

**Expected result:** Monitor page will show sensors instead of "System Offline"

**DO THIS NOW!** 🚀
