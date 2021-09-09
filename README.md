# Sparcv8 Based Project
A CPU project based on the unprivileged version of the SPARCv8 standard:
https://sparc.org/technical-documents/

The aim is not compliance, and I doubt I'll achieve it at any point.
A bit of a toy project to get me ready for my UMD EE classes.

Currently written in Verilog , but this is part of a 3 step project:
1. Implement SPARCv8 in Verilog
2. Modify SPARCv8 for SystemVerilog
3. Implement SPARCv9 in Systemverilog

This made the most sense to me, as I know both Verilog and SystemVerilog to a reasonable degree, but it's really difficult for me to focus on the code with the kind of freedom SystemVerilog affords me.

Based around the DE0-CV board for now, but as I move up I might have to push to the Genesys.

__Resources:__
* Open Source UART Interface by wd5gnr - https://github.com/wd5gnr/icestickPWM/tree/master/v2/cores/osdvu
* Open Source SD card interface by WangXuan95 - https://github.com/WangXuan95/FPGA-SDcard-Reader/blob/master/README_en.md
* VGA text mode reference by OSDEV.org- https://wiki.osdev.org/Text_UI
* VGA text mode reference on Wikipedia - https://en.wikipedia.org/wiki/VGA_text_mode
* VGA reference ProjectF- https://projectf.io/posts/fpga-graphics/
* PWM reference by fpga4fun - https://www.fpga4fun.com/PWM_DAC_1.html

# In Progress
(Still working on these, I wanted easily doable goals that show my ability to
integrate IP's, create IP's, memory map IO, and utilize sparc features)
- Trap handling
- Data memory write and read
- TSO compliant handler
- Block ram and internal rom
- Error mode LED
- ASR Registers - partially finished, but I plan to add watchdog timer and clock register here

Peripherals in progress:
- SPARCv9 style watchdog timer
- SPARCv9 style TICK register - ASR
- 6 x 7 segment display - Hex, based on one ASR register
- UARTx2 - GPIO pins used, and LED indicators employed for UART 1
- SD card - Memory map a few sectors
- 7 user LED's - Memory mapped, 1 address each, pwm

# In testing
(Finished and synthesized but not tested)
- Fetch
- Decode
- Execute (for most instructions)
- Register write (for most instructions)
- Register windows (NWINDOWS=3)
- Compliant ALU with signed and unsigned multiply/divide

# Future plans
(Likely going to be finished after my ENEE350 classe in preparation for my 400 level digital design classes)
- Multi-stage pipeline
- SDRAM usage as main memory
- I and D cache
- FPU
- An actual (not space expensive altera blob) divider
- VGA Text mode - using block ram as character storage and the sdram as actual storage, ASR to activate
- Memory mapped switches
- PS/2 keyboard input
- More IO interfaces, possible SPI, I2C, GPIO
- Better debugging, some kind of wishbone debug or NIOS
