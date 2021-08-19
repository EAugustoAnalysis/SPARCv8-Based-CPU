# Sparcv8 Based Project
A CPU project based on the unprivileged version of the SPARCv8 standard:
https://sparc.org/technical-documents/

The aim is not compliance, and I doubt I'll achieve it at any point.
A bit of a toy project to get me ready for my ENEE350 class at UMD next semester.

Based around the DE0-CV board, but I'm planning a fomu version with USB uart based on Silice HDL.

Resources Borrowed:
* Open Source UART Interface by wd5gnr - https://github.com/wd5gnr/icestickPWM/tree/master/v2/cores/osdvu
* Open Source SD card interface by WangXuan95 - https://github.com/WangXuan95/FPGA-SDcard-Reader/blob/master/README_en.md

# In Progress
(Still working on these, I wanted easily doable goals that show my ability to
integrate IP's, create IP's, memory map IO, and utilize sparc features)
- Fetch/Decode and top level iu module
- Trap handling
- ASR Registers - partially finished, but I plan to add watchdog timer and clock register here
- UARTx2 - GPIO pins used, and LED indicators employed for UART 1
- Block ram and internal rom
- Memory handler
- Reset mode LED
- VGA Text mode-based HDMI using SDRAM
- 7 user LED's - Memory mapped
- 6 x 7 segment display - Hex, based on one ASR register
- SPARCv9 style watchdog timer - ASR
- SPARCv9 style Clock register - ASR

# In testing
(Finished and synthesized but not tested)
- PC/nPC registers
- Register windows (NWINDOWS=3)
- Y register
- Trap base register
- Compliant ALU with signed and unsigned multiply/divide

# Future plans
(May not get to these this summer)
- Multi-stage pipeline
- An actual divider
- I and D cache
- Modify the memory manager to be wishbone based for portability
- FPU
- Memory mapped switches
- DDR3 ram usage
- Expanding SD card
- SD card - Memory map a few sectors
- PS/2 keyboard input
- SMA ADC
- More IO interfaces, possible SPI, I2C, GPIO
- Better debugging, some kind of wishbone debug or NIOS
- NIOS USB UART
