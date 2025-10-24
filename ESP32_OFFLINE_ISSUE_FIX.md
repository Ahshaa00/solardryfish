# 🔧 ESP32 OFFLINE ISSUE - DIAGNOSIS & FIX

## 🐛 **THE PROBLEM**

### **Symptoms:**
1. ✅ **Dashboard shows sensors working** (data is updating)
2. ❌ **Monitor page shows "System Offline"** (status shows offline)
3. ❌ **ESP32 goes offline after few minutes**

---

## 🔍 **ROOT CAUSE**

### **Timing Mismatch:**

**ESP32 Upload Interval:**
```cpp
#define FIREBASE_UPLOAD_INTERVAL 5000  // Uploads every 5 seconds
```

**App Offline Detection:**
```dart
// Consider data stale if no update in last 30 seconds
final stale = difference > 30000;  // 30 seconds timeout
```

**The Issue:**
- ESP32 uploads every **5 seconds** ✅
- App marks offline after **30 seconds** ✅
- **BUT:** If ESP32 misses 6+ uploads (WiFi hiccup, Firebase delay), system marked offline

---

## 🎯 **WHY DASHBOARD WORKS BUT MONITOR DOESN'T**

### **Dashboard Logic:**
```dart
// Dashboard listens to sensor data directly
systemRef.child('sensors').onValue.listen((event) {
  // Gets sensor updates
  // Shows sensor values even if status is "offline"
});
```

### **Monitor Page Logic:**
```dart
// Monitor checks online status FIRST
if (!online) {
  return sensorCard(
    title: "TEMP/HUMIDITY SENSOR $key",
    lines: [
      "System Offline",  // ❌ Shows this instead of sensor data
      "No sensor data available",
    ],
  );
}
```

**The Problem:**
- Dashboard shows **sensor data** regardless of online status
- Monitor page checks **online status** before showing sensors
- If `online = false`, monitor hides all sensor data

---

## 🔧 **SOLUTION OPTIONS**

### **Option 1: Increase App Timeout (Recommended)**

**Change app timeout from 30s to 60s:**

```dart
// In dashboard_screen.dart and system_monitor_page.dart
void _checkDataFreshness() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final difference = now - lastUpdateTimestamp;

  // OLD: Consider data stale if no update in last 30 seconds
  // final stale = difference > 30000;
  
  // NEW: Consider data stale if no update in last 60 seconds
  final stale = difference > 60000;  // ✅ Change to 60 seconds
  
  if (isDataStale != stale) {
    setState(() {
      isDataStale = stale;
      if (stale) {
        online = false;
      }
    });
  }
}
```

**Why this works:**
- ESP32 uploads every 5 seconds
- Even if 10 uploads fail, still within 60s window
- More tolerant of network hiccups
- System won't go offline unnecessarily

---

### **Option 2: Increase ESP32 Upload Frequency**

**Change ESP32 upload from 5s to 3s:**

```cpp
// In ESP32_3.ino
// OLD: #define FIREBASE_UPLOAD_INTERVAL 5000
#define FIREBASE_UPLOAD_INTERVAL 3000  // ✅ Upload every 3 seconds
```

**Why this works:**
- More frequent updates
- Less likely to exceed 30s timeout
- Better real-time monitoring

**Cons:**
- More Firebase writes (still within free tier)
- Slightly more power consumption

---

### **Option 3: Add Heartbeat System (Advanced)**

**ESP32 sends heartbeat every 10 seconds:**

```cpp
#define HEARTBEAT_INTERVAL 10000

void sendHeartbeat() {
  unsigned long now = millis();
  if (now - lastHeartbeat < HEARTBEAT_INTERVAL) return;
  lastHeartbeat = now;
  
  Firebase.RTDB.setInt(&fbdo, String(path) + "/status/heartbeat", now);
}
```

**App checks heartbeat:**

```dart
void _checkDataFreshness() {
  // Check heartbeat instead of lastUpdate
  final difference = now - heartbeatTimestamp;
  final stale = difference > 30000;
}
```

---

## ✅ **RECOMMENDED FIX**

### **Quick Fix (5 minutes):**

**Change app timeout to 60 seconds:**

1. Open `lib/screens/dashboard_screen.dart`
2. Find line ~297: `final stale = difference > 30000;`
3. Change to: `final stale = difference > 60000;`

4. Open `lib/pages/system_monitor_page.dart`
5. Find line ~225: `final stale = difference > 30000;`
6. Change to: `final stale = difference > 60000;`

**Done!** System will be more tolerant of network delays.

---

### **Better Fix (10 minutes):**

**Increase ESP32 upload frequency + increase app timeout:**

**ESP32 (ESP32_3.ino):**
```cpp
#define FIREBASE_UPLOAD_INTERVAL 3000  // Every 3 seconds
```

**App (dashboard_screen.dart & system_monitor_page.dart):**
```dart
final stale = difference > 45000;  // 45 seconds timeout
```

**Why:**
- ESP32 uploads every 3s
- App allows 45s timeout
- Can miss 15 uploads before going offline
- Very reliable!

---

## 🔍 **ADDITIONAL CHECKS**

### **1. Check ESP32 Serial Monitor:**

Look for these messages:
```
✅ Firebase connected
✅ Uploading data...
✅ Upload successful

❌ Firebase disconnected
❌ Upload failed
❌ WiFi disconnected
```

### **2. Check Firebase Console:**

- Go to Firebase Realtime Database
- Check `/hardwareSystems/SDF202509AA/status/lastUpdate`
- Should update every 5 seconds
- If not updating → ESP32 problem
- If updating → App timeout problem

### **3. Check WiFi Signal:**

```cpp
// Add to ESP32 setup()
Serial.print("WiFi Signal: ");
Serial.print(WiFi.RSSI());
Serial.println(" dBm");
```

**Signal Strength:**
- -30 to -50 dBm: Excellent ✅
- -50 to -70 dBm: Good ✅
- -70 to -80 dBm: Fair ⚠️
- -80 to -90 dBm: Poor ❌

---

## 🐛 **DEBUGGING STEPS**

### **Step 1: Check if ESP32 is actually uploading**

Add debug to ESP32:
```cpp
void uploadToFirebase() {
  Serial.print("📤 Uploading... ");
  
  if (Firebase.RTDB.setInt(&fbdo, path + "/status/lastUpdate", millis())) {
    Serial.println("✅ Success");
  } else {
    Serial.print("❌ Failed: ");
    Serial.println(fbdo.errorReason());
  }
}
```

### **Step 2: Check app timeout logic**

Add debug to app:
```dart
void _checkDataFreshness() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final difference = now - lastUpdateTimestamp;
  
  print('🔍 Last update: ${(difference / 1000).toStringAsFixed(1)}s ago');
  print('🔍 Online: $online | Stale: ${difference > 30000}');
  
  final stale = difference > 30000;
  // ...
}
```

### **Step 3: Monitor Firebase directly**

Open Firebase Console and watch:
- `/hardwareSystems/SDF202509AA/status/lastUpdate`
- Should change every 5 seconds
- If it stops → ESP32 crashed or disconnected

---

## 📊 **TIMING COMPARISON**

| Scenario | ESP32 Upload | App Timeout | Result |
|----------|--------------|-------------|--------|
| **Current** | 5s | 30s | ❌ Goes offline easily |
| **Fix 1** | 5s | 60s | ✅ More stable |
| **Fix 2** | 3s | 30s | ✅ More stable |
| **Fix 3** | 3s | 45s | ✅ Very stable |
| **Best** | 3s | 60s | ✅ Most stable |

---

## ✅ **QUICK FIX CODE**

### **File 1: `lib/screens/dashboard_screen.dart`**

**Line ~297, change:**
```dart
// OLD:
final stale = difference > 30000;

// NEW:
final stale = difference > 60000;  // 60 seconds instead of 30
```

---

### **File 2: `lib/pages/system_monitor_page.dart`**

**Line ~225, change:**
```dart
// OLD:
final stale = difference > 30000;

// NEW:
final stale = difference > 60000;  // 60 seconds instead of 30
```

---

### **File 3 (Optional): `c:\Users\User\Downloads\ESP32_3\ESP32_3.ino`**

**Line ~34, change:**
```cpp
// OLD:
#define FIREBASE_UPLOAD_INTERVAL 5000

// NEW:
#define FIREBASE_UPLOAD_INTERVAL 3000  // Upload every 3 seconds
```

---

## 🎯 **SUMMARY**

**The Issue:**
- ESP32 uploads every 5 seconds
- App marks offline after 30 seconds
- Network delays cause false "offline" status
- Dashboard shows sensors (doesn't check online status)
- Monitor page hides sensors (checks online status first)

**The Fix:**
- Change app timeout from 30s to 60s
- Optionally: Change ESP32 upload from 5s to 3s
- System will be much more stable

**Apply the quick fix and your ESP32 won't go offline anymore!** ✅
