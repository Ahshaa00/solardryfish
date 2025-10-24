SolarDryFish - Wiring Guide (Option 2: Individual Circuit Protection)

**Configuration:** Individual Fuses for Each Circuit  
**Complexity:** Professional  
**Best For:** Reliable operation, fault isolation, remote locations

---

COMPLETE COMPONENT LIST
Power System
Component	Quantity	Specifications	Notes
Battery	4	12V 12Ah	Parallel configuration
Solar Panel	1	160W	Charging source
MPPT Charge Controller	1	30A	Charging management
Buck Converter	1	DFR0379 (12V→5V)	ESP32 power
Fuse & Holder	8	1×20A, 3×15A, 2×10A, 2×spare	Individual circuit protection (need 2 more 15A)
Microcontrollers
Component	Quantity	Specifications	Notes
Arduino MEGA 2560	1	-	Main controller
ESP32	1	WiFi module	WiFi communication
Sensors
Component	Quantity	Specifications	Notes
SHT31 (Temp/Humidity)	4	I2C, 3.3V	Chamber monitoring
Raindrop Sensor	4	Analog	Rain detection
Photoresistor (LDR)	4	Analog	Light detection
Motors & Drivers
Component	Quantity	Specifications	Notes
BTS7960 Motor Driver	2	43A peak	Motor control
Lid Motor	1	Mitsubishi Lancer PW	Opens/closes lid
Flip Motor	1	5840-31ZY Worm Gear	Flips mechanism
Limit Switch	4	NO type	Position detection
Heater System
Component	Quantity	Specifications	Notes
PTC Heater with Fan	1	12V	Temperature control
MOSFET (IRFZ44N)	2	Logic-level	Heater/Fan control
Diode (1N4007)	2	Flyback protection	Inductive load protection
Resistor 1kΩ	2	Gate current limiting	MOSFET protection
Resistor 10kΩ	2	Pull-down resistor	MOSFET control
Display & Input
Component	Quantity	Specifications	Notes
LCD Display	1	20×4 Parallel	Status display
Push Button	4	UP, DOWN, OK, BACK	User control
Potentiometer	1	10kΩ	Contrast adjustment
Resistor 220Ω	1	Backlight limiting	LED protection
Resistors (Voltage Dividers & Misc)
Component	Quantity	Value	Purpose
Resistor	1	33kΩ	Battery monitor divider
Resistor	1	10kΩ	Battery monitor divider
Resistor	1	1kΩ	Serial level shifter
Resistor	1	2kΩ	Serial level shifter
Resistor	4	10kΩ	Light sensor pull-down
Wiring & Connectors
Component	Quantity	Type	Notes
12 AWG Wire (Red)	5 meters	Stranded copper	Battery, motors, heater (+) - for 20A fuse
12 AWG Wire (Black)	5 meters	Stranded copper	Ground returns (-) - for 20A fuse
18 AWG Wire (Red)	2 meters	Stranded copper	Buck, MEGA VIN (+)
18 AWG Wire (Black)	2 meters	Stranded copper	Buck, MEGA GND (-)
22 AWG Jumper Wire	50+ pieces	M-M, F-F, M-F	Signals, sensors, GPIO (✅ Have)
Ring Terminals (12 AWG)	10 pieces	Crimp type	Battery connections
Ring Terminals (18 AWG)	10 pieces	Crimp type	Buck/MEGA connections
Heat Shrink Tubing	1 meter	Assorted sizes	Wire protection
Wire Ferrules (optional)	20 pieces	Various sizes	Terminal connections

**✅ OPTION 2 BENEFITS:**
- Individual circuit protection (fault isolation)
- Better component protection
- Easier troubleshooting
- System stays partially operational during faults
- No software load management needed

**📋 NEED TO BUY:**
- 2× 15A blade fuses
- 3× Additional inline fuse holders

**📄 ALTERNATIVE:** See WIRING_GUIDE_OPTION1_SIMPLE_SETUP.md for simpler 3-fuse setup

SYSTEM ARCHITECTURE
Block Diagram
┌─────────────────────────────────────────────────────────────┐
│                     SOLAR SYSTEM                             │
│  Solar Panel (160W) → MPPT Controller → Battery Pack         │
│                                              (4×12V 12Ah)    │
└─────────────────┬───────────────────────────────────────────┘
│ 12V Main Bus
┌─────────┼─────────┐
│         │         │
┌───▼──┐  ┌──▼──┐  ┌───▼────┐
│ Buck │  │MEGA │  │Motors/ │
│ 5V   │  │CTRL │  │Heater  │
└───┬──┘  └──┬──┘  └────────┘
│       │
┌───▼───┐   │ Serial
│ ESP32 │◄──┤ (9600)
│ WiFi  │   │
└───────┘   │
└──► Sensors (I2C, Analog)
System Components
Component	Role	Voltage
Solar Panel	Power generation	Variable
Battery (4×12V)	Energy storage	12V
MPPT Controller	Charging management	12V → 12V
Buck Converter	Voltage step-down	12V → 5V
ESP32	WiFi communication	5V input, 3.3V logic
Arduino MEGA	Main controller	7-12V input, 5V logic
Motors	Lid & Flip control	12V
Heater	Temperature control	12V
Sensors	Environment monitoring	3.3V / 5V mixed




POWER SYSTEM
Battery Configuration
Battery	Voltage	Capacity	Connection
Battery 1	12Vq	12Ah	Parallel (+)
Battery 2	12V	12Ah	Parallel (+)
Battery 3	12V	12Ah	Parallel (+)
Battery 4	12V	12Ah	Parallel (+)
Total	12V	48Ah	Combined
Power Distribution (Option 2: Individual Fuses)
┌──────────────────────────────┐
│   Battery Bank (12V, 48Ah)   │
└──────────────┬───────────────┘
│
[20A Main Fuse] ← Overall system protection
│
┌──────┴──────┐
│             │
┌───▼────┐   ┌────▼────┐
│  MPPT  │   │  12V    │
│ Solar  │   │  Bus    │
└────────┘   └────┬────┘
│
┌──────────┼──────────┼──────────┼──────────┐
│          │          │          │          │
[10A]    [15A]    [15A]    [10A]    [15A]
│          │          │          │          │
Buck     MEGA     Lid      Flip     PTC
5V       Logic    Motor    Motor    Heater
│          │          │          │          │
ESP32    Sensors  BTS7960  BTS7960  MOSFETs

Fuse Configuration (Option 2)
Circuit	Fuse	Current (Normal)	Peak Current	Purpose
Main Battery	20A	10-15A	20A	Overall system protection
Buck Converter	10A	0.5A	1A	ESP32 circuit protection
MEGA + Logic	15A	0.3A	0.5A	Controller protection
Lid Motor	15A	2-5A	8A	Lid motor circuit protection
Flip Motor	10A	2-3A	5A	Flip motor circuit protection
PTC Heater	15A	10A	15A	Heater circuit protection

✅ Benefits: Individual faults don't take down entire system
✅ Easier troubleshooting: Blown fuse identifies problem circuit
✅ Better component protection: Smaller fuses blow faster

📋 Shopping List:
- Have: 2×20A, 2×10A, 2×15A ✅
- Need: 2×15A fuses
- Need: 3×Inline fuse holders

MICROCONTROLLER CONNECTIONS
ESP32 Pin Mapping
Pin	Function	Connection	Voltage
VIN	Power In	Buck 5V output	5V
3.3V	Power Out	SHT31 sensors	3.3V
GND	Ground	Common GND	0V
GPIO 16	I2C2 SDA	SHT31 #3 & #4	3.3V logic
GPIO 17	I2C2 SCL	SHT31 #3 & #4	3.3V logic
GPIO 21	I2C1 SDA	SHT31 #1 & #2	3.3V logic
GPIO 22	I2C1 SCL	SHT31 #1 & #2	3.3V logic
GPIO 25	Serial RX2	MEGA Pin 18 (TX1)	3.3V input
GPIO 26	Serial TX2	MEGA Pin 19 (RX1)	3.3V output
Arduino MEGA Pin Mapping
Pin	Function	Connection	Voltage
VIN	Power In	Battery (12V)	7-12V
5V	Power Out	Sensors, LCD, Buttons	5V
GND	Ground	Common GND	0V
2	PWM	Flip L_PWM	5V PWM
3	PWM	Flip R_PWM	5V PWM
5	PWM	Lid R_PWM	5V PWM
6	PWM	Lid L_PWM	5V PWM
7	PWM	LCD Backlight	5V PWM
8	Digital	LCD RS	5V
9	Digital	LCD E	5V
10-13	Digital	LCD D4-D7	5V
18	TX1	ESP32 GPIO 25	5V out
19	RX1	ESP32 GPIO 26	3.3V in
30-33	Digital	Buttons	5V input
34-35	Digital	Lid Motor EN	5V out
36-37	Digital	MOSFET Gates	5V out
38-39	Digital	Flip Motor EN	5V out
40-43	Digital	Limit Switches	5V input
A0-A3	Analog	Light Sensors	0-5V input
A4-A7	Analog	Rain Sensors	0-5V input
A8	Analog	Battery Monitor	0-3.3V input
Serial Communication
Level Shifter (MEGA TX → ESP32 RX):

MEGA Pin 18 (5V) ──[1kΩ]──┬──[2kΩ]── GND
│
ESP32 GPIO 25 (3.3V)

Output: 5V × (2kΩ ÷ 3kΩ) = 3.33V ✅
Direction	From	To	Pins	Baud
MEGA → ESP32	MEGA TX1 (18)	ESP32 RX2 (25)	Via voltage divider	9600
ESP32 → MEGA	ESP32 TX2 (26)	MEGA RX1 (19)	Direct (3.3V OK)	9600
Common	Both	Both	GND	Ground
I2C Bus Configuration
I2C Bus 1 (GPIO 21/22):
├─ SHT31 #1 (Address 0x44) ADDR→GND
└─ SHT31 #2 (Address 0x45) ADDR→3.3V

I2C Bus 2 (GPIO 16/17):
├─ SHT31 #3 (Address 0x44) ADDR→GND
└─ SHT31 #4 (Address 0x45) ADDR→3.3V
MOTOR & MECHANICAL SYSTEMS
Lid Motor System
MEGA Pins:
34 → R_EN
35 → L_EN
5 (PWM) → R_PWM
6 (PWM) → L_PWM

┌─── BTS7960 #1 ───┐
│                   │
Motor Control       12V Power
(Enable/PWM)          │
│            B+→Battery
│            B-→GND
└─→ M+/M- → Motor

Limit Switches:
Pin 40 → Fully Open
Pin 41 → Fully Closed
Pin	Component	Purpose
34	BTS7960 R_EN	Forward enable
35	BTS7960 L_EN	Reverse enable
5	BTS7960 R_PWM	Forward speed (0-255)
6	BTS7960 L_PWM	Reverse speed (0-255)
40	Limit switch	Open position detector
41	Limit switch	Close position detector
Flip Motor System
MEGA Pins:
38 → R_EN
39 → L_EN
2 (PWM) → R_PWM
3 (PWM) → L_PWM

┌─── BTS7960 #2 ───┐
│                   │
Motor Control       12V Power
(Enable/PWM)          │
│            B+→Battery
│            B-→GND
└─→ M+/M- → Motor

Limit Switches:
Pin 42 → Position 1
Pin 43 → Position 2
Pin	Component	Purpose
38	BTS7960 R_EN	Forward enable
39	BTS7960 L_EN	Reverse enable
2	BTS7960 R_PWM	Forward speed (0-255)
3	BTS7960 L_PWM	Reverse speed (0-255)
42	Limit switch	Position 1 detector
43	Limit switch	Position 2 detector
Limit Switches
Switch	Location	MEGA Pin	Status
Lid Open	Top-left	40	HIGH = Open / LOW = Limit Hit
Lid Close	Bottom-right	41	HIGH = Closed / LOW = Limit Hit
Flip Pos1	Horizontal	42	HIGH = Pos1 / LOW = Limit Hit
Flip Pos2	Vertical	43	HIGH = Pos2 / LOW = Limit Hit

SENSORS & MONITORING
Temperature & Humidity (SHT31)
Bus 1 (GPIO 21/22):
┌─ Sensor #1 (0x44)
│  ├─ VCC → 3.3V
│  ├─ GND → GND
│  ├─ SDA → GPIO 21
│  └─ SCL → GPIO 22
│
└─ Sensor #2 (0x45)
├─ VCC → 3.3V
├─ GND → GND
├─ SDA → GPIO 21
├─ SCL → GPIO 22
└─ ADDR → 3.3V

Bus 2 (GPIO 16/17):
┌─ Sensor #3 (0x44)
│  ├─ VCC → 3.3V
│  ├─ GND → GND
│  ├─ SDA → GPIO 16
│  └─ SCL → GPIO 17
│
└─ Sensor #4 (0x45)
├─ VCC → 3.3V
├─ GND → GND
├─ SDA → GPIO 16
├─ SCL → GPIO 17
└─ ADDR → 3.3V
Sensor	Address	Bus	Location	Range
SHT31 #1	0x44	GPIO 21/22	Chamber 1	-10°C to +85°C
SHT31 #2	0x45	GPIO 21/22	Chamber 2	-10°C to +85°C
SHT31 #3	0x44	GPIO 16/17	Chamber 3	-10°C to +85°C
SHT31 #4	0x45	GPIO 16/17	Chamber 4	-10°C to +85°C
⚠️ CRITICAL: SHT31 requires 3.3V ONLY. Using 5V will damage sensors.
Rain Sensors (Analog)
MEGA Analog Pins:

A4 ◄─ Rain Sensor #1 (Corner 1)
VCC → 5V
GND → GND
AO → A4

A5 ◄─ Rain Sensor #2 (Corner 2)
VCC → 5V
GND → GND
AO → A5

A6 ◄─ Rain Sensor #3 (Corner 3)
VCC → 5V
GND → GND
AO → A6

A7 ◄─ Rain Sensor #4 (Corner 4)
VCC → 5V
GND → GND
AO → A7

Reading: 0-1023
Dry: 800-1023
Wet: 0-400
Pin	Sensor	Location	Status
A4	Rain #1	Corner 1	HIGH = Dry / LOW = Wet
A5	Rain #2	Corner 2	HIGH = Dry / LOW = Wet
A6	Rain #3	Corner 3	HIGH = Dry / LOW = Wet
A7	Rain #4	Corner 4	HIGH = Dry / LOW = Wet
Light Sensors (LDR/Photoresistor)
MEGA Analog Pins:

A0 ◄─ Light Sensor #1 (Corner 1)
VCC → 5V (via sensor)
GND → [10kΩ] → GND
Middle → A0

A1 ◄─ Light Sensor #2 (Corner 2)
A2 ◄─ Light Sensor #3 (Corner 3)
A3 ◄─ Light Sensor #4 (Corner 4)

Reading: 0-1023
Bright: 100-300
Normal: 400-600
Dark: 800-1023
Pin	Sensor	Location	Status
A0	Light #1	Corner 1	HIGH = Dark / LOW = Bright
A1	Light #2	Corner 2	HIGH = Dark / LOW = Bright
A2	Light #3	Corner 3	HIGH = Dark / LOW = Bright
A3	Light #4	Corner 4	HIGH = Dark / LOW = Bright
Battery Monitor
Voltage Divider:

12V Bat+ ──[33kΩ]──┬──[10kΩ]── GND
│
MEGA A8

Output: 2.8V (safe for MEGA)
Calculation: 12V × (10kΩ ÷ 43kΩ) = 2.79V

In Code:
Reading = analogRead(A8)
Voltage = (Reading / 1023) × 5 × 4.3

Example: A8 = 590 → Voltage ≈ 12.3V
Component	Value	Purpose
R1	33kΩ	High side resistor
R2	10kΩ	Low side resistor
MEGA Pin	A8	Voltage input
Ratio	0.233	Divider ratio
DISPLAY & CONTROL
LCD Display (20×4 Parallel)
LCD Pins → MEGA Pins:

Pin 1 (GND) → GND
Pin 2 (VCC) → 5V
Pin 3 (VO) → 10kΩ Pot (contrast)
Pin 4 (RS) → 8
Pin 5 (RW) → GND
Pin 6 (E) → 9
Pin 11 (D4) → 10
Pin 12 (D5) → 11
Pin 13 (D6) → 12
Pin 14 (D7) → 13
Pin 15 (LED+) → 7 (via 220Ω)
Pin 16 (LED-) → GND

Backlight Control (PWM):
5V ──[220Ω]── LCD LED+ (Pin 15)
LCD LED- (Pin 16) ── GND
MEGA Pin	LCD Pin	Function
8	4	Register Select
9	6	Enable
10	11	Data 4
11	12	Data 5
12	13	Data 6
13	14	Data 7
7 (PWM)	15	Backlight (via 220Ω)
Control Buttons
MEGA Pins:

Pin 30 ──┬─→ Button UP
└─→ GND

Pin 31 ──┬─→ Button DOWN
└─→ GND

Pin 32 ──┬─→ Button OK
└─→ GND

Pin 33 ──┬─→ Button BACK
└─→ GND

Configuration: INPUT_PULLUP (no external resistors needed)
Pin	Button	Action	Pull-up
30	UP	Scroll up	Internal
31	DOWN	Scroll down	Internal
32	OK	Select/Confirm	Internal
33	BACK	Go back	Internal
Contrast & Backlight
Contrast Adjustment:
5V ──[10kΩ Pot]── GND
│
└─ LCD Pin 3

Backlight PWM:
MEGA Pin 7 ──[220Ω]── LCD LED+
PWM Range: 0-255 (dimming)
WIRING SUMMARY
Power Rails
12V Rail: Battery → Fuse 20A → MPPT, Motors, Heater
5V Rail: Buck Converter → ESP32, LCD, Buttons, Sensors
3.3V Rail: ESP32 3.3V → SHT31 sensors ONLY
GND Rail: All components (star configuration)
Complete Pin Reference
System	MEGA Pins	ESP32 Pins	Voltage	Function
Power	VIN, 5V, GND	VIN, 3.3V, GND	Mixed	Supply
Serial	18, 19	25, 26	5V/3.3V	Communication
I2C Bus 1	-	21, 22	3.3V	Sensors 1-2
I2C Bus 2	-	16, 17	3.3V	Sensors 3-4
Lid Motor	5, 6, 34, 35	-	5V PWM	Control
Flip Motor	2, 3, 38, 39	-	5V PWM	Control
Heater	36, 37	-	5V PWM	Control
Buttons	30-33	-	5V Input	Control
LCD	7-13	-	5V	Display
Analog	A0-A8	-	0-5V	Sensors
Heater Control (MOSFETs)
Heater Circuit:

12V+ ──→ PTC Heater ──┬─→ MOSFET Drain
│
[Diode]
│
GND ← MOSFET Source

Gate Drive:
MEGA Pin 36 ──[1kΩ]── MOSFET Gate
[10kΩ pull-down]
│
GND

Pin	Component	Purpose
36	MOSFET #1	Heater control
37	MOSFET #2	Fan control
-	1kΩ resistor	Gate limiter
-	10kΩ resistor	Pull-down
-	Diode	Flyback protection

SAFETY GUIDELINES {#safety}
Critical Safety Checks
⚠️ SHT31: 3.3V ONLY (5V destroys sensor - $30+)
⚠️ Voltage Divider Required (MEGA TX → ESP32 RX)
⚠️ Common GND Essential (All grounds connected)
⚠️ All Fuses Installed (No bypassing)
⚠️ Limit Switches First (Motor safety)
⚠️ Diodes on MOSFETs (Inductive protection)
Before Power-On Checklist
☐ All GND connections verified
☐ Voltage divider tested (1kΩ + 2kΩ)
☐ Buck converter outputting 5V
☐ No short circuits visible
☐ All fuses installed
☐ SHT31 on 3.3V (not 5V)
☐ Limit switches working
☐ MOSFET gates have resistors
☐ Battery fully charged
☐ No loose wires
Voltage Safety
Rail	Expected	Safe Range	Critical
Battery 12V	12V	11-14V	>14V = overcharge
Buck 5V	5.0V	4.8-5.2V	<4.8V = ESP32 reset
ESP32 3.3V	3.3V	3.0-3.6V	>3.6V = damage
SHT31 3.3V	3.3V	3.0-3.6V	5V = destroyed
Motor Safety
Item	Action	Reason
Test Low Speed	PWM 50-100	Detect issues early
Install Limits	Before power	Prevent over-run
Listen for Noise	Motor running	Detect problems
Stop on Limit Hit	Automatic	Mechanical protection
Never Force	Stop if stuck	Prevent damage

