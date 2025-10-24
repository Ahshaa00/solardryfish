# Sensor 1 Not Showing in Monitor Page - Debug Instructions

## Current Situation

**Firebase Data:** Sensor 1 is working correctly ✅
```
sensors/tempHumid/1/
  ├── connected: true
  ├── working: true
  ├── status: "OK"
  └── value/
      ├── temp: 29.45358
      └── hum: 76.86671
```

**Dashboard:** Shows "All sensors working" ✅

**Monitor Page:** Shows "Status: Unknown - Sensor not connected or no valid data" ❌

## What I Added

Enhanced debug logging to diagnose why sensor 1 data isn't displaying:

### 1. Listener Debug Logs
When data is received from Firebase:
```dart
print('🔍 Monitor: Received sensor $i data: $sensorData');
```

### 2. Display Debug Logs
When building the sensor card:
```dart
print('🔍 Monitor: Sensor $key data: $data');
print('🔍 Monitor: Sensor $key - connected: $connected, working: $working, valueMap: $valueMap');
```

### 3. Validation Debug Logs
When validation fails:
```dart
print('❌ Monitor: Sensor $key validation failed - connected: $connected, valueMap: $valueMap, temp: $tempValue, hum: $humValue');
```

## How to Debug

### Step 1: Rebuild the App
```bash
flutter clean
flutter pub get
flutter run
```

### Step 2: Open Monitor Page
Navigate to the System Monitor page in your app.

### Step 3: Check Flutter Logs
Look for these debug messages in your console:

#### Expected Output (if working):
```
🔍 Monitor: Received sensor 1 data: {connected: true, working: true, status: OK, value: {temp: 29.45, hum: 76.87}, ...}
🔍 Monitor: Sensor 1 data: {connected: true, working: true, status: OK, value: {temp: 29.45, hum: 76.87}, ...}
🔍 Monitor: Sensor 1 - connected: true, working: true, valueMap: {temp: 29.45, hum: 76.87}
```

#### Problematic Output (if failing):
```
⚠️ Monitor: Sensor 1 has empty data
```
OR
```
🔍 Monitor: Sensor 1 data: {}
❌ Monitor: Sensor 1 validation failed - connected: false, valueMap: null, temp: null, hum: null
```

## Possible Issues & Solutions

### Issue 1: Empty Data Map
**Log shows:** `⚠️ Monitor: Sensor 1 has empty data`

**Cause:** The individual listener isn't receiving data for sensor 1

**Solution:** Check Firebase path - ensure it's exactly `sensors/tempHumid/1/`

### Issue 2: Data Received But Not Parsed
**Log shows:** `Received sensor 1 data: {...}` but `Sensor 1 data: {}`

**Cause:** Data is being received but not stored in `tempHumidData` map

**Solution:** Check if `setState()` is being called properly

### Issue 3: Value Map is Null
**Log shows:** `valueMap: null`

**Cause:** The `value` field is missing or structured differently

**Solution:** Check Firebase structure - should be `value/temp` and `value/hum`

### Issue 4: Connected is False
**Log shows:** `connected: false`

**Cause:** The `connected` field in Firebase is false or missing

**Solution:** Check ESP32 is setting `connected: true` for sensor 1

## What to Share

After rebuilding and opening the Monitor page, share:

1. **All log lines** that start with `🔍 Monitor: Sensor 1`
2. **All log lines** that start with `⚠️ Monitor: Sensor 1`
3. **All log lines** that start with `❌ Monitor: Sensor 1`

Example format:
```
🔍 Monitor: Received sensor 1 data: {connected: true, ...}
🔍 Monitor: Sensor 1 data: {connected: true, ...}
🔍 Monitor: Sensor 1 - connected: true, working: true, valueMap: {temp: 29.45, hum: 76.87}
```

## Quick Test

To verify the fix is working for other sensors, check the logs for sensor 2:
```
🔍 Monitor: Received sensor 2 data: ...
🔍 Monitor: Sensor 2 data: ...
```

If sensor 2 shows complete data but sensor 1 doesn't, it's a Firebase data issue.
If both show empty data, it's a listener issue.

## Expected Result After Fix

Monitor page should show:
```
TEMP/HUMIDITY SENSOR 1
Temp: 29.5°C
Humidity: 77%
Status: OK
Working ✅
```

## Files Modified

- ✅ `lib/pages/system_monitor_page.dart` - Added comprehensive debug logging

## Next Steps

1. Rebuild the app
2. Open Monitor page
3. Copy all debug logs for sensor 1
4. Share the logs so we can identify the exact issue
