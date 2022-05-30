ACL-Tester-Design-MB-S7

Lightly verified on Arty-S7-25 hardware on 2022-05-30, #1.
Development for this board still in progress.

Indexes 4,4 for the presets threshold appear to work.

It is necessary to attach the TTY emulator to the UART on
Linux, before launching the application over JTAG.

Note that all 6 LEDs are disabled for lack of FPGA
fabric resources. They were originally driven by PWM,
and a different approach may be attempted.

NO WARRANTY
MIT LICENSE
Copyright (c) 2021-2022 Timothy Stotts
