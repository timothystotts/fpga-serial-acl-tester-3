ACL-Tester-Design-MB-S7

Verified project TCL regeneration from a Linux project
on Windows 10 Pro.
Verified on Arty-S7-25 hardware on 2022-06-10, #1.

Indexes 4,4 for the presets threshold appear to work.

It is necessary to attach the TTY emulator to the UART,
before launching the application over JTAG. Otherwise,
the board may glitch or reset into an unknown state.

Note that all 6 LEDs are now enabled. They are operated
via GPIO instead of PWM outputs. The PWM v2.0 IP block
provided by Digilent Inc. required too many FPGA resources
to be able to fit both the Microblaze Application CPU and
PWMs in the fabric.

NO WARRANTY
MIT LICENSE
Copyright (c) 2021-2022 Timothy Stotts
