# fpga-serial-acl-tester-3

FPGA Serial ACL Tester Version 3

by Timothy Stotts

This project version replaces
[fpga-serial-acl-tester-1](https://github.com/timothystotts/fpga-serial-acl-tester-1)
and
[fpga-serial-acl-tester-2](https://github.com/timothystotts/fpga-serial-acl-tester-2)
.

Now with support for:

- Digilent Inc. Arty S7-25 FPGA development board containing a small Xilinx Spartan-7 FPGA
- Digilent Inc. Arty A7-100 FPGA development board containing a large Xilinx Artix-7 FPGA
- Digilent Inc. Zybo Z7-20 APSoC development board containing a moderate Zyng-7000 SoC.

Note that clerical corrections were completed in branch `bugs/various_defects`
and merged to branch `main`. These corrections include updates to comments,
commenting style, and whitespace.

Notes:
- The photos of Arty S7-25 assembly currently show PMOD ACL2 at JB and PMOD CLS at JA; but the three RTL code projects have the PMOD ACL2 at JA and the PMOD CLS at JB. This discrepancy will be remedied at a later time.
- The MicroBlaze example followed this tutorial as a starting point:
- [https://digilent.com/reference/learn/programmable-logic/tutorials/arty-getting-started-with-microblaze-servers/start](https://digilent.com/reference/learn/programmable-logic/tutorials/arty-getting-started-with-microblaze-servers/start)
- Note that the MicroBlaze example requires Xilinx Vivado 2021.2. The DDR MIG is driven by two MMCM clocks in a way that is possibly incompatible with newer versions of Vivado. Newer versions of Vivado may require a revised block design to achieve a functional design.

## Description
A small FPGA project of different implementations for testing Measurement and Activity Events of a SPI accelerometer.
The Xilinx MicroBlaze design and the three HDL designs can now target either of
two FPGA development boards produced by Digilent Inc; one being lower cost.
	- Digilent Inc. Arty-S7-25 FPGA development board containing a small Xilinx Spartan-7 FPGA
	- Digilent Inc. Arty-A7-100 FPGA development board containing a large Xilinx Artix-7 FPGA

Three peripherals are used: Digilent Inc. Pmod ACL2, Digilent Inc. Pmod CLS., Digilent Inc. Pmod SSD.

Additionally, the Xilinx Zynq design targets the
Digilent Inc. Zybo-Z7-20 FPGA development board containing a Xilinx Zynq-7000 APSoC.
Three peripherals are used: Digilent Inc. Pmod ACL2, Digilent Inc. Pmod CLS., Digilent Inc. Pmod SSD.

The design is broken into six groupings.
The first group targets the Digilent Inc. Arty A7-100 development board.
The second group targets the Digilent Inc. Arty S7-25 development board.
The next three groups target either of the Digilent Inc. Arty-S7-25 or
Digilent Inc. Arty A7-100 development boards.
The last group targets the Digilent Inc. Zybo Z7-20 development board.
The projects are likely portable to the smaller Arty A7-35 and Zybo-Z7-10
respectively as the designs are low resource utilization.

The folder ACL-Tester-Design-MB contains a Xilinx Vivado IP Integrator plus
Xilinx Vitis design.
A microblaze soft CPU is instantiated to talk with board components,
an accelerometer peripheral,
a 16x2 character LCD peripheral,
and a two-digit Seven Segment Display.
Sources to be incorporated into a Xilinx Vitis project contain
a very small FreeRTOS program in C; drivers
for the peripherals, a real-time task to operate and poll the accelerometer,
two real-time tasks to display data, and a real-time task to color-mix RGB LEDs.
(None of the real-time tasks demonstrate executing with a precise timer, but only
demonstrate a best-effort execution; as such, calling these tasks real-time
may be a misnomer. Executing these tasks with a precise timer can be achieved
with FreeRTOS; but the benefit does not outweigh the added complexity for
this specific implementation.)  

The folder ACL-Tester-Design-MB-S7 contains a Xilinx Vivado IP Integrator plus
Xilinx Vitis design.
A microblaze soft CPU is instantiated to talk with board components,
an accelerometer peripheral,
a 16x2 character LCD peripheral,
and a two-digit Seven Segment Display.
Sources to be incorporated into a Xilinx Vitis project contain
a very small FreeRTOS program in C; drivers
for the peripherals, a real-time task to operate and poll the accelerometer
and light the LEDs, plus two real-time tasks to display data.
(None of the real-time tasks demonstrate executing with a precise timer, but only
demonstrate a best-effort execution; as such, calling these tasks real-time
may be a misnomer. Executing these tasks with a precise timer can be achieved
with FreeRTOS; but the benefit does not outweigh the added complexity for
this specific implementation.)  

The folder ACL-Tester-Design-SV contains a Xilinx Vivado project with sources
containing only SystemVerilog RTL modules. Plain HDL without a soft CPU or C code is authored to
talk with board components, an accelerometer peripheral, and a 16x2 character LCD peripheral.
The project uses clock enable pulses instead of clock dividers
as much as possible throughout the design.
Note that an init script and pin constraints are included for both the Arty-A7-100 and the Arty-S7-25.

The folder ACL-Tester-Design-Verilog contains a Xilinx Vivado project with sources
containing only Verilog RTL modules. Plain HDL without a soft CPU or C code is authored to
talk with board components, an accelerometer peripheral, and a 16x2 character LCD peripheral.
The project uses clock enable pulses instead of clock dividers
as much as possible throughout the design.
Note that an init script and pin constraints are included for both the Arty-A7-100 and the Arty-S7-25.

The folder ACL-Tester-Design-VHDL contains a Xilinx Vivado project with sources
containing only VHDL-2002 and VHDL-2008 RTL modules. Plain HDL without a soft CPU or C code
is authored to
talk with board components, an accelerometer peripheral, and a 16x2 character LCD peripheral.
The project uses clock enable pulses instead of clock dividers
as much as possible throughout the design.
Note that an init script and pin constraints are included for both the Arty A7-100 and the Arty S7-25.
The design additionally includes a modifiable OS-VVM
test-bench in VHDL-2008 to exercise the RTL in simulation. Only a single default test is
implemented; and the test-bench is almost the same for SystemVerilog, Verilog, and VHDL RTL
variants. The test-bench can be executed with the open source program GHDL.

The folder ACL-Tester-Design-Zynq contains a Xilinx Vivado IP Integrator plus Xilinx Vitis design.
The Zynq hard ARM CPU #0 is configured to talk with board components, a SPI MEMS accelerometer peripheral,
a 16x2 character LCD peripheral, and a two-digit 7-segment display. Its functionality is mostly
equivalent to that of the ACL-Tester-Design-MB design.

These six groupings of design provide equivalent functionality, excepting that the HDL designs provide
additional pulsing effect of the board's three-emitter RGB LEDs for esthetics.
Additionally:
- the Arty A7-100 Xilinx MicroBlaze design operates the RGB and Basic LEDs with PWMs instead of GPIO.
- the Arty S7-25 Xilinx MicroBlaze design operates the RGB and Basic LEDs with GPIO instead of PWMs.
- the Zynq design produces equivalent functionality as the MB (MicroBlaze) desgin, but targting a Zybo Z7-20 board instead.

Further notes.
The Xilinx MicroBlaze and Xilinx Zynq designs
implement an alternative IP module instead of Pmod SSD user IP, called MuxSSD. This allows the
FreeRTOS C code to implement a software driver to update two registers on the MuxSSD IP that control
the discrete segments of each of the two Seven Segment digit emitters. The MuxSSD IP in the IPI-BD
takes care of multiplexing the two digits with only 8 general purpose signals. The FreeRTOS
program can write one or both digits at any time and expect continued display of both digits
with no necessary timer usage for GPIO multiplexing in the CPU user code.

### Naming conventions notice
The Pmod peripherals used in this project connect via a standard bus technology design called SPI.
The use of MOSI/MISO terminology is considered obsolete. COPI/CIPO is now used. The MOSI signal on a
controller can be replaced with the title 'COPI'. Master and Slave terms are now Controller and Peripheral.
Additional information can be found [here](https://www.oshwa.org/a-resolution-to-redefine-spi-signal-names).
The choice to use COPI and CIPO instead of SDO and SDI for single-direction bus signals is simple.
On a single peripheral bus with two data lines of fixed direction, the usage of the signal name
"SDO" is dependent on whether the Controller or the Peripheral is the chip being discussed;
whereas COPI gives the exact direction regardless of which chip is being discussed. The author
of this website agrees with the open source community that the removal of offensive language from
standard terminology in engineering is a priority.

### Project information document:

./Serial ACL Readings Tester - Refreshed.pdf

[Serial ACL Readings Tester info](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/Serial%20ACL%20Readings%20Tester%20-%20Refreshed.pdf)

### Diagrams design document (only the HDL designs):

./ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams.pdf

[Serial ACL Design Diagrams info](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams.pdf)

#### Target device assembly: Arty-A7-100 with Pmod ACL2, Pmod CLS, Pmod SSD, on extension cables
![Target device assembly](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/img_serial-acl-tester-assembled-20190718.jpg)

#### Target device execution: Arty-A7-100 with Pmod ACL2, Pmod CLS, Pmod SSD, on extension cables
![Target device assembly executing](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/img_serial-acl-tester-executing-a-20210217.jpg)

#### Target device execution: Arty-S7-25 with Pmod ACL2, Pmod CLS, Pmod SSD, on extension cables
![Target device assembly executing](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/img_serial-acl-tester-s7-executing.jpg)

#### Target device assembly: Zybo-Z7-20 with Pmod ACL2, Pmod CLS, Pmod SSD, on extension cables
![Target device assembly](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/img_serial-acl-tester-assembled-20200731.jpg)


#### Block diagram architecture of the HDL designs:
![ACL Tester Architecture Diagram](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-Architecture%201.svg)

#### Top Port diagram architecture of the HDL designs:
![ACL Tester Top Ports Diagram](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-Top-Ports.svg)

#### Tester FSM diagram of the HDL designs:
![ACL Tester FSM Diagram](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-Tester-FSM.svg)

#### LCD FSM diagram of the HDL designs:
![LCD FSM Diagram](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-LCD-FSM.svg)

#### UART Feed FSM diagram of the HDL designs:
![UART Feed FSM Diagram](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-UARTfeed.svg)

#### UART TX ONLY FSM diagram of the HDL designs:
![UART Feed FSM Diagram](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-UART-Tx-FSM.svg)

#### 4-input Multi-Debouncer for 4 exclusve inputs, such as switches or buttons, of the HDL designs:
![4-bit Multi-Debouncer](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-multi-debounce.svg)

#### ACL2 Custom Driver External Ports diagram of the HDL designs:
![ACL2 Custom Driver Ports](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-ACL2-ports.svg)

#### ACL2 Custom Driver Internal Ports diagram of the HDL designs:
![ACL2 Custom Driver Ports, Internal](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-ACL2-ports-internal.svg)

#### ACL2 Custom Driver readings Stream FSM:
![ACL2 Custom Driver readings Stream FSM](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-StreamFSM.svg)

#### Pmod ACL2 Standard SPI custom driver FSM for operating the standard SPI driver to configuration and operate the modes of the ADXL362 accelerometer chip of the Pmod ACL2:
![ACL2 Custom Driver readings driver FSM](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-ADXL362-driver-FSM.svg)

#### Generic Standard SPI Single Chip protocol bus driver, used by the ACL2 driver and the CLS driver
![Generic Standard SPI Single Chip bus driver](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-SPI-generic-FSM.svg)

#### CLS Custom Driver External Ports diagram of the HDL designs:
![CLS Custom Driver Ports](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-CLS-ports.svg)

#### CLS Custom Driver Internal Ports diagram of the HDL designs:
![CLS Custom Driver Ports, Internal](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-CLS-ports-internal.svg)

#### Pmod CLS Standard SPI custom driver FSM for operating the standard SPI driver to send text line refreshes to the ATmega48 microcontroller chip of the Pmod CLS:
![CLS Custom Driver readings driver FSM](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-CLS-driver-FSM.svg)

#### Threshold Preset Selector - design implements 0 to 9, and back. The diagram is for h0 to hF, and back.
![Threshold Preset Selector FSM](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-thresh-preset-sel-FSM.svg)

#### Utility FSMs: one-shot FSM and synchonous pulse stretcher
![Utility FSMs, one-shot, pulse stretcher](https://github.com/timothystotts/fpga-serial-acl-tester-3/blob/main/ACL-Tester-Design-Documents/ACL-Tester-Design-Diagrams-Utility-FSMs.svg)
