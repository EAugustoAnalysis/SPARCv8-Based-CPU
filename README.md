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
(Still working on these)
- Fetch/Decode and top level iu module
- Trap handling
- ASR Registers - partially finished, but I plan to add watchdog timer and clock register here
- UARTx2 - GPIO pins used, and LED indicators employed for UART 1
- Block ram and internal rom
- Memory handler
- Power LED
- SD card
- 4 user LED's - ASR based
- SPARCv9 style watchdog timer
- SPARCv9 style Clock register

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
- User switches - memory mapped?
- DDR3 ram usage
- VGA Text mode-based HDMI using AD7513 and DDR3
- SMA ADC
- More IO interfaces, possible SPI, I2C, GPIO
- Better debugging, some kind of wishbone debug or NIOS
- NIOS USB UART
