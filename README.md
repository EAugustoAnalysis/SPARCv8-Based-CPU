# Sparcv8 Based Project
A CPU project based on the unprivileged version of the SPARCv8 standard:
https://sparc.org/technical-documents/

The aim is sort-of compliance. I doubt I'll achieve it at any point, but I do wish to get pretty close.
There's a lot of SPARC stuff that's ambiguous or left to the direction of the programmer, so I have a lot of wiggle room.

A bit of a toy project to get me ready for my UMD EE classes.

Currently written in Verilog , but this is part of a 3 step project:
1. Implement SPARCv8 in Verilog
2. Modify SPARCv8 for SystemVerilog
3. Implement SPARCv9 in Systemverilog

This made the most sense to me, as I know both Verilog and SystemVerilog to a reasonable degree, but it's really difficult for me to focus on the code with the kind of freedom SystemVerilog affords me to get lost in typedef land.

# In Progress
(Still working on these, I wanted easily doable goals that show my ability to
integrate IP's, create IP's, memory map IO, and utilize sparc features)
- Trap handling
- Data memory write and read
- TSO compliant memory handler
- Block ram and internal rom
- ASR Registers - partially finished, but I plan to add a few features here

Peripherals in progress:
- SPARCv9 style watchdog timer
- SPARCv9 style TICK register - in ASR
- 6 x 7 segment display - Hex, packed into one ASR register
- UART TX/RX
- PS/2 keyboard input
- SD card - Memory map a few sectors
- Error mode LED

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
- SDRAM usage as main memory, expanded memory handler
- I and D cache as BRAMs
- FPU

Peripherals planned:
- An actual (not space expensive altera blob) divider
- VGA Text mode - using block ram as character storage and the sdram as actual storage, ASR to activate
- Memory mapped IO
- More IO interfaces, possible SPI, I2C, GPIO
- Better debugging, some kind of wishbone debug or NIOS interface

# Resources and References
__IP Resources:__

Borrowed IP's and a few essential IP references:
* Open Source UART Interface by wd5gnr - https://github.com/wd5gnr/icestickPWM/tree/master/v2/cores/osdvu
* Open Source SD card interface by WangXuan95 - https://github.com/WangXuan95/FPGA-SDcard-Reader/blob/master/README_en.md
* VGA text mode reference by OSDEV.org- https://wiki.osdev.org/Text_UI
* VGA text mode reference on Wikipedia - https://en.wikipedia.org/wiki/VGA_text_mode
* VGA reference ProjectF- https://projectf.io/posts/fpga-graphics/
* PWM reference by fpga4fun - https://www.fpga4fun.com/PWM_DAC_1.html
* OpenCores Wishbone Requirements - https://opencores.org/howto/wishbone

__Testing Tools:__

This is mainly just stuff for testbench automation:
* The Unicorn Emulator (SPARCv8 emulator) - https://www.unicorn-engine.org/docs/tutorial.html
* Unicorn SPARC Example (in java, though I use python) - https://github.com/unicorn-engine/unicorn/blob/master/bindings/java/samples/Sample_sparc.java
* 

__References:__

This project has gone through 5 redesigns, and I started this with zero knowledge of processor design, so I did quite a bit of reading. On top of my ENEE350 class, which has (as of 9/8/2021) taught me a lot already, I have these resources to thank for my philosophies and knowledge. Like all great failed projects, I hope that if mine never goes anywhere it becomes a cool list of references on CPU implementation:

FPGA Help:
* Logic Design and Verification using SystemVerilog - Donald Thomas
* Synthesizable SystemVerilog by Sutherland-HDL https://sutherland-hdl.com/papers/2013-SNUG-SV_Synthesizable-SystemVerilog_paper.pdf
* SystemVerilog FPGA synthesis guide by Southerland-HDL - https://sutherland-hdl.com/papers/2014-DVCon_ASIC-FPGA_SV_Synthesis_paper.pdf
* SystemVerilog data packing by Amiq - https://www.amiq.com/consulting/2017/05/29/how-to-pack-data-using-systemverilog-streaming-operators/
* Quartus block RAM info by Intel - https://www.intel.com/content/www/us/en/programmable/quartushelp/13.0/mergedProjects/hdl/vlog/vlog_pro_ram_inferred.htm

CPU Concepts:
* Computer Architectures (Not sure who wrote this) - http://paginapessoal.utfpr.edu.br/gortan/aoc/transparencias/t01_intro_aoc/literatura/Wiki_Computer_Architectures_Overview2.pdf
* An excellent guide to pipelining by MS Schmalz -  https://www.cise.ufl.edu/~mssz/CompOrg/CDA-pipe.html

RISC CPU Help:
* The now-missing resource "Building a RISC System in an FPGA" - http://ee.sharif.edu/~micro2/files/ebooks/Building%20a%20RISC%20System%20in%20an%20FPGA.pdf
* Andreas Schweizer's guide to CPU Implementation in VHDL - https://blog.classycode.com/implementing-a-cpu-in-vhdl-part-1-6afd4c1ed491
* Dr. Sauermann's guide to CPU implementation in VHDL - https://opencores.org/usercontent/doc/1262707254
* Cornell's RISC-V Philosophy guide by Professor Weatherspoon - https://slideplayer.com/slide/17089957/

Verification:
* The ZIPCPU guide to formal verification - https://zipcpu.com/formal/2019/11/18/genuctrlr.html
* Wishbone formal verification by ZIPCPU - http://zipcpu.com/zipcpu/2017/11/07/wb-formal.html

SOC Design Tutorials:
* Wishbone implementation by ZIPCPU - https://zipcpu.com/blog/2017/06/08/simple-wb-master.html
* Wishbone interconnect implementation by ZIPCPU http://zipcpu.com/blog/2017/06/22/simple-wb-interconnect.html
* Debugger implementation philosophy by ZIPCPU - https://zipcpu.com/zipcpu/2017/08/25/hw-debugging.html
* SPI Master by ZIPCPU - https://zipcpu.com/blog/2018/08/16/spiflash.html
* Wishbone FAQ by PLDWorld - http://www.pldworld.com/_hdl/2/_ip/-silicore.net/wishfaq.htm

SPARC stuff I read when I needed help and inspiration:
* OpenSPARC Internals - David L. Weaver
* Peter Magnusson's excellent analysis of SPARCv8 register windows and their flaws - http://icps.u-strasbg.fr/people/loechner/public_html/enseignement/SPARC/sparcstack.html
* SPARC instruction comparisons https://arcb.csc.ncsu.edu/~mueller/codeopt/codeopt00/notes/sparc.html
* The Gasilier LEON2 XST SPARCv7 Manual (used this for pipelining considerations)  - https://www.cse.wustl.edu/~roger/465M/leon2-1.0.23-xst.pdf
* Atmel's SPARCv7 Manual (For SoC design considerations) - http://ww1.microchip.com/downloads/en/DeviceDoc/doc4148.pdf
* UNM Professor Maccabe's SPARC assembly reference - https://www.cs.unm.edu/~maccabe/classes/341/labman/labman.html
* Professor Maccabe's register window reference - https://www.cs.unm.edu/~maccabe/classes/341/labman/node11.html#SECTION001100000000000000000
* The Enchanted Learning SPARCv8 guide (I have no idea why this exists, this is mainly an online learning site for children, but it's really good) - https://www.enchantedlearning.com/sparc/
* A bit of SPARC datapath info by Northwestern U professors Gupta and Parashar - https://users.cs.northwestern.edu/~agupta/_projects/sparc_simulator/Datapath%20for%20SPARC%20Processor.htm
* SuperSPARC Guide by Ozan Aktan - https://slideplayer.com/slide/3944474/
* The TEMLIB project was a great resource for SPARCv8 knowledge - http://temlib.org/site/?p=85
* A partial verilog SPARCv7 Implementation by Synopsy (Includes a cool Verilog tutorial) - https://course.ece.cmu.edu/~ece447/s13/lib/exe/fetch.php?media=goodrtl-parkin.pdf
