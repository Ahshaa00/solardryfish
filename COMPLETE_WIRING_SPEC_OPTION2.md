# 🔌 COMPLETE WIRING SPECIFICATION - OPTION 2 (PROFESSIONAL)

## ⚡ **SYSTEM OVERVIEW**

**Configuration:** Individual circuit protection with solar fuses  
**MPPT Fuse:** 30A (recommended for 48Ah battery)  
**Total Fuse Holders:** 8  
**Total Fuses:** 12

---

## 🔧 **COMPLETE FUSE LAYOUT**

```
Solar Panel (160W, ~18V, 8.9A)
    │
    │ 10 AWG wire
    │
    [10A Fuse] ← Solar panel protection
    │
    ▼
MPPT Charger (40A max, 12V out)
    │
    │ 10 AWG wire
    │
    [30A Fuse] ← MPPT to battery protection
    │
    ▼
Battery Pack (4×12V 12Ah = 48Ah)
    │
    │ 10 AWG wire
    │
    [20A Fuse] ← Main system protection
    │
    ▼
12V Bus
    │
    ├─[10A]─→ Buck Converter (12V→5V, 7A max) ─→ ESP32
    │   │ 14 AWG wire
    │
    ├─[15A]─→ MEGA + Sensors (12V, 3A max)
    │   │ 14 AWG wire
    │
    ├─[15A]─→ Lid Motor Driver (12V, 12A peak)
    │   │ 12 AWG wire
    │
    ├─[10A]─→ Flip Motor Driver (12V, 8A peak)
    │   │ 14 AWG wire
    │
    └─[15A]─→ Heater + Fan (12V, 10A max)
        │ 12 AWG wire
```

---

## 📏 **AWG WIRE GUIDE**

### **Wire Gauge by Current:**

| Current | AWG Size | Diameter | Max Length | Use For |
|---------|----------|----------|------------|---------|
| **30-40A** | **10 AWG** | 2.6mm | 3m | Solar, MPPT, Battery main |
| **20-25A** | **12 AWG** | 2.1mm | 5m | Main bus, motors, heater |
| **10-15A** | **14 AWG** | 1.6mm | 5m | MEGA, Buck, Flip motor |
| **5-10A** | **16 AWG** | 1.3mm | 3m | Sensors, signals |
| **<5A** | **18-22 AWG** | 0.6-1.0mm | 2m | GPIO, I2C, sensors |

---

## 🛒 **COMPLETE SHOPPING LIST**

### **FUSES (12 total):**
```
SOLAR SIDE:
□ 2× 10A blade fuses        ($2)
  - 1× Solar panel (active)
  - 1× Spare

□ 2× 30A blade fuses        ($3)
  - 1× MPPT output (active)
  - 1× Spare

LOAD SIDE:
□ 2× 20A blade fuses        ($2) ✅ Have
  - 1× Main bus (active)
  - 1× Spare

□ 4× 15A blade fuses        ($4)
  - 1× MEGA (active) ✅ Have
  - 1× Lid motor (active) ⚠️ Need
  - 1× Heater (active) ✅ Have
  - 1× Spare ⚠️ Need

□ 2× 10A blade fuses        ($2) ✅ Have
  - 1× Buck (active)
  - 1× Flip motor (active)

───────────────────────────
YOU HAVE: 6 fuses (2×20A, 2×15A, 2×10A)
NEED TO BUY: 6 fuses (2×10A, 2×30A, 2×15A)
TOTAL COST: $11
```

---

### **FUSE HOLDERS (8 total):**
```
□ 1× 10A inline holder      ($1)  - Solar panel
□ 1× 30A inline holder      ($3)  - MPPT output
□ 1× 20A inline holder      ($2)  - Main bus
□ 2× 15A inline holders     ($4)  - MEGA, Lid motor
□ 1× 15A inline holder      ($2)  - Heater
□ 2× 10A inline holders     ($2)  - Buck, Flip motor

───────────────────────────
TOTAL COST: $14
```

---

### **POWER WIRES:**

**10 AWG (High Current - Solar & Battery):**
```
□ 3m × 10 AWG red wire      ($6)
  - Solar panel to MPPT: 1m
  - MPPT to battery: 1m
  - Battery to main fuse: 1m

□ 3m × 10 AWG black wire    ($6)
  - Ground returns

TOTAL: $12
```

**12 AWG (Medium Current - Motors & Heater):**
```
□ 6m × 12 AWG red wire      ($9)
  - Main bus to motors: 3m
  - Main bus to heater: 1m
  - Distribution: 2m

□ 6m × 12 AWG black wire    ($9)
  - Ground returns

TOTAL: $18
```

**14 AWG (Low-Medium Current - MEGA & Buck):**
```
□ 3m × 14 AWG red wire      ($3)
  - Main bus to MEGA: 1m
  - Main bus to Buck: 1m
  - Distribution: 1m

□ 3m × 14 AWG black wire    ($3)
  - Ground returns

TOTAL: $6
```

**18 AWG (Signals & Sensors):**
```
□ 2m × 18 AWG red wire      ($2)
  - Buck to ESP32: 0.5m
  - Sensor power: 1.5m

□ 2m × 18 AWG black wire    ($2)
  - Ground returns

TOTAL: $4
```

**22 AWG Jumper Wires:**
```
✅ 50+ pieces M-M, F-F, M-F (Already have)
  - GPIO connections
  - I2C sensors
  - Control signals
```

---

### **CONNECTORS & ACCESSORIES:**
```
□ 15× Ring terminals (10 AWG)   ($5)  - Solar & battery
□ 20× Ring terminals (12 AWG)   ($6)  - Motors & heater
□ 15× Ring terminals (14 AWG)   ($4)  - MEGA & Buck
□ 10× Ring terminals (18 AWG)   ($2)  - Sensors
□ 2m Heat shrink tubing         ($3)  - Wire protection
□ 20× Wire ferrules (optional)  ($3)  - Terminal connections

───────────────────────────
TOTAL: $23
```

---

## 💰 **TOTAL COST BREAKDOWN**

```
FUSES:
- Solar/MPPT fuses (new):   $5
- Load fuses (new):         $6
                          ────
Subtotal:                  $11

FUSE HOLDERS:              $14

WIRES:
- 10 AWG (solar/battery):  $12
- 12 AWG (motors/heater):  $18
- 14 AWG (MEGA/Buck):      $6
- 18 AWG (sensors):        $4
                          ────
Subtotal:                  $40

CONNECTORS:                $23

═══════════════════════════
GRAND TOTAL:               $88
```

---

## 📋 **WIRE LENGTH SUMMARY**

### **By AWG Size:**
```
10 AWG:  6m total (3m red + 3m black)
12 AWG: 12m total (6m red + 6m black)
14 AWG:  6m total (3m red + 3m black)
18 AWG:  4m total (2m red + 2m black)
22 AWG: ✅ Have enough
```

---

## 🔌 **DETAILED WIRING CONNECTIONS**

### **1. Solar Panel to MPPT:**
```
Solar Panel (+) ─┬─ 10 AWG red (1m) ─┬─ [10A Fuse] ─┬─ MPPT (+)
                 │                     │               │
Solar Panel (-) ─┴─ 10 AWG black (1m) ┴───────────────┴─ MPPT (-)
```

### **2. MPPT to Battery:**
```
MPPT (+) ─┬─ 10 AWG red (1m) ─┬─ [30A Fuse] ─┬─ Battery (+)
          │                    │               │
MPPT (-) ─┴─ 10 AWG black (1m) ┴───────────────┴─ Battery (-)
```

### **3. Battery to Main Bus:**
```
Battery (+) ─┬─ 10 AWG red (1m) ─┬─ [20A Fuse] ─┬─ 12V Bus (+)
             │                    │               │
Battery (-) ─┴─ 10 AWG black (1m) ┴───────────────┴─ 12V Bus (-)
```

### **4. Main Bus to Buck Converter:**
```
12V Bus (+) ─┬─ 14 AWG red (1m) ─┬─ [10A Fuse] ─┬─ Buck (+)
             │                    │               │
12V Bus (-) ─┴─ 14 AWG black (1m) ┴───────────────┴─ Buck (-)

Buck 5V (+) ─┬─ 18 AWG red (0.5m) ─┬─ ESP32 5V
             │                      │
Buck GND    ─┴─ 18 AWG black (0.5m) ┴─ ESP32 GND
```

### **5. Main Bus to MEGA:**
```
12V Bus (+) ─┬─ 14 AWG red (1m) ─┬─ [15A Fuse] ─┬─ MEGA VIN
             │                    │               │
12V Bus (-) ─┴─ 14 AWG black (1m) ┴───────────────┴─ MEGA GND
```

### **6. Main Bus to Lid Motor Driver:**
```
12V Bus (+) ─┬─ 12 AWG red (1.5m) ─┬─ [15A Fuse] ─┬─ BTS7960 #1 (+)
             │                      │               │
12V Bus (-) ─┴─ 12 AWG black (1.5m) ┴───────────────┴─ BTS7960 #1 (-)
```

### **7. Main Bus to Flip Motor Driver:**
```
12V Bus (+) ─┬─ 14 AWG red (1.5m) ─┬─ [10A Fuse] ─┬─ BTS7960 #2 (+)
             │                      │               │
12V Bus (-) ─┴─ 14 AWG black (1.5m) ┴───────────────┴─ BTS7960 #2 (-)
```

### **8. Main Bus to Heater:**
```
12V Bus (+) ─┬─ 12 AWG red (1m) ─┬─ [15A Fuse] ─┬─ MOSFET Heater (+)
             │                    │               │
12V Bus (-) ─┴─ 12 AWG black (1m) ┴───────────────┴─ Heater (-)
```

---

## ⚡ **CURRENT CAPACITY BY AWG**

### **Safe Continuous Current:**
```
10 AWG: 30A continuous (40A peak)
12 AWG: 20A continuous (25A peak)
14 AWG: 15A continuous (20A peak)
16 AWG: 10A continuous (13A peak)
18 AWG:  7A continuous (10A peak)
22 AWG:  3A continuous (5A peak)
```

### **Voltage Drop (12V system, 3m length):**
```
10 AWG @ 30A: 0.3V drop (2.5%)  ✅ Excellent
12 AWG @ 20A: 0.4V drop (3.3%)  ✅ Good
14 AWG @ 15A: 0.5V drop (4.2%)  ✅ Acceptable
18 AWG @ 7A:  0.4V drop (3.3%)  ✅ Good
```

---

## 🎯 **WHY THESE WIRE SIZES?**

### **10 AWG for Solar/Battery:**
- **Solar panel:** 8.9A max, but use 10 AWG for future expansion
- **MPPT output:** 30A charging current
- **Battery main:** 20A load + 30A charging = 50A peak
- **10 AWG handles 30-40A safely**

### **12 AWG for Motors/Heater:**
- **Lid motor:** 12A peak
- **Heater:** 10A continuous
- **12 AWG handles 20-25A safely**

### **14 AWG for MEGA/Buck/Flip:**
- **MEGA:** 3A max
- **Buck:** 7A max
- **Flip motor:** 8A peak
- **14 AWG handles 15-20A safely**

### **18 AWG for Low Power:**
- **ESP32:** 1A max
- **Sensors:** 0.5A total
- **18 AWG handles 7-10A safely**

---

## ✅ **INSTALLATION CHECKLIST**

### **Phase 1: Solar Side**
```
□ Install 10A fuse holder on solar (+) wire
□ Connect solar panel to MPPT with 10 AWG wire
□ Install 30A fuse holder on MPPT output
□ Connect MPPT to battery with 10 AWG wire
□ Test: Check voltage at battery (should be 12-14V)
```

### **Phase 2: Main Bus**
```
□ Install 20A fuse holder on battery (+) wire
□ Create 12V bus distribution point
□ Connect battery to bus with 10 AWG wire
□ Test: Check voltage at bus (should be 12V)
```

### **Phase 3: Individual Circuits**
```
□ Install 10A fuse holder for Buck converter
□ Connect Buck with 14 AWG wire
□ Install 15A fuse holder for MEGA
□ Connect MEGA with 14 AWG wire
□ Install 15A fuse holder for Lid motor
□ Connect Lid motor driver with 12 AWG wire
□ Install 10A fuse holder for Flip motor
□ Connect Flip motor driver with 14 AWG wire
□ Install 15A fuse holder for Heater
□ Connect Heater with 12 AWG wire
```

### **Phase 4: Testing**
```
□ Check all fuse ratings
□ Check all wire connections
□ Measure voltage at each circuit
□ Test each circuit individually
□ Check for voltage drop
□ Verify no shorts
```

---

## 🔒 **SAFETY NOTES**

### **Wire Sizing Rules:**
1. ✅ Always use wire rated for 125% of max current
2. ✅ Use thicker wire for longer runs
3. ✅ Never use wire smaller than recommended
4. ✅ Use proper crimp connectors
5. ✅ Protect all connections with heat shrink

### **Fuse Placement:**
1. ✅ Fuse on positive (+) wire only
2. ✅ Fuse as close to power source as possible
3. ✅ Never bypass or jumper a fuse
4. ✅ Always use correct fuse rating
5. ✅ Keep spare fuses in toolbox

---

## 📞 **QUICK REFERENCE**

### **Wire Color Code:**
```
RED:    Positive (+) 12V
BLACK:  Negative (-) Ground
YELLOW: Signal/Control (optional)
GREEN:  Ground (optional)
```

### **Fuse Quick Guide:**
```
10A:  Solar panel, Buck, Flip motor
15A:  MEGA, Lid motor, Heater
20A:  Main bus
30A:  MPPT output
```

### **AWG Quick Guide:**
```
10 AWG: Solar, MPPT, Battery (30-40A)
12 AWG: Motors, Heater (20-25A)
14 AWG: MEGA, Buck, Flip (10-15A)
18 AWG: ESP32, Sensors (5-10A)
```

---

## ✅ **FINAL SUMMARY**

**Total Investment: $88**
- Fuses: $11
- Fuse holders: $14
- Wires: $40
- Connectors: $23

**Complete Protection:**
- ✅ Solar panel protected (10A)
- ✅ MPPT output protected (30A)
- ✅ Main system protected (20A)
- ✅ Each circuit individually protected
- ✅ Proper wire sizing for all currents
- ✅ Professional-grade installation

**This is the complete, safe, professional setup!** 🔒⚡
