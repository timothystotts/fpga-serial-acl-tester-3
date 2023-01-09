# ACL-Tester-Design-Verilog

## Verification on 2023-01-09

Manually tested on Arty A7-100 hardware on 2023-01-09, #2.
Index 4 of the threshold presets tested to work.
Two times deadlock observed after bitstream loading with switch 0 or 1 in
ON position. Could not reproduce the deadlock again.
Checked on hardware:
- LCD Display (raw and formatted via button press)
- UART Printing (raw and formatted via button press)
- Accelerometer readings switching between Measurement Mode and Linked Mode
- Accelerometer data sensible when positioning PMOD ACL2
- Presets #4 Activity and #4 Inactivity (selected via button press)
- LEDs 2 and 3 sensible for Activity and Inactivity indications

Manually tested on Arty S7-25 hardware on 2023-01-09, #2.
Index 4 of the threshold presets tested to work.
Checked on hardware:
- LCD Display (raw and formatted via button press)
- UART Printing (raw and formatted via button press)
- Accelerometer readings switching between Measurement Mode and Linked Mode
- Accelerometer data sensible when positioning PMOD ACL2
- Presets #4 Activity and #4 Inactivity (selected via button press)
- LEDs 2 and 3 sensible for Activity and Inactivity indications
Note that the JA and JB were swapped in the constraints versus the pictures in
the informational documentation. PMOD ACL2 is actually at JA and not JB. PMOD
CLS is actually at JB and not JA. The swap must have occurred after photos and
before committing sources to GIT.

## Verification on 2022-01-02

Verified on Arty-A7-100 hardware on 2022-01-02, #1.
Index 4 of the threashold presets tested to work.

Verified on Arty-S7-25 hardware on 2022-01-02, #1.
Index 4 of the threashold presets tested to work.

NO WARRANTY
MIT LICENSE
Copyright (c) 2020-2023 Timothy Stotts
