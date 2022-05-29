##------------------------------------------------------------------------------
## MIT License
##
## Copyright (c) 2020-2021 Timothy Stotts
##
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to deal
## in the Software without restriction, including without limitation the rights
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
## copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
##
## The above copyright notice and this permission notice shall be included in
## all copies or substantial portions of the Software.
##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
## SOFTWARE.
##------------------------------------------------------------------------------

## This file is a general .xdc for the Arty S7-25 Rev. E, specific to the ACL2 Tester clocking.
## WARNING:
## Note that all input and output delays are ballpark values and are not representative
## of a thorough examination of the board layout design. A fully proper configuration
## would require use of advanced tools to examine and simulate the board trace delays
## by export of a IBIS file from Vivado and import of that file into an advanced
## board layout design tool.

# The main input clock, 12 MHz
#create_clock -add -name sys_clk_pin -period 83.333 -waveform {0 41.667} [get_ports { CLK12MHZ }];

# The following are generated clocks as implemented by clock divider components.
# The syntax of the TCL command requires specification of either a port or a pin
# for both the source clock output register and the clock divider output register.
# It appears that the MMCM cannot have one of its ports referenced with [get_ports {}] ,
# but instead requires to have one of its pins referenced wtih [get_pins {}] .
# This causes a synthesis warning of the internal synthesized pin not yet existing;
# but synthesis and implementation still succeed in the end and still create the
# generated clock and still constrain related logic according to the generated
# clock.
#create_generated_clock -name genclk5mhz -source [get_pins u_pmod_acl2_custom_driver/u_pmod_generic_spi_solo/u_spi_1x_clock_divider/s_clk_out_reg/C] -divide_by 4 [get_pins u_pmod_acl2_custom_driver/u_pmod_generic_spi_solo/u_spi_1x_clock_divider/s_clk_out_reg/Q]
#create_generated_clock -name genclk625khz -source [get_pins u_pmod_cls_custom_driver/u_pmod_generic_spi_solo/u_spi_1x_clock_divider/s_clk_out_reg/C] -divide_by 32 [get_pins u_pmod_cls_custom_driver/u_pmod_generic_spi_solo/u_spi_1x_clock_divider/s_clk_out_reg/Q]
# The Seven Segment Display digit multiplexor clock is actually 100 Hz, but we
# overconstrain at 10000 Hz as Vivado cannot # process a 100 Hz constraint.
# The actual clock rate of 100 Hz is too low of a speed for Vivado to process.
#create_generated_clock -name clk100hz_ssd -source [get_pins u_one_pmod_ssd_display/u_pmod_ssd_out/u_clock_divider/s_clk_out_reg/C] -divide_by 2000 [get_pins u_one_pmod_ssd_display/u_pmod_ssd_out/u_clock_divider/s_clk_out_reg/Q]

# The following are input and output virtual clocks for constaining the estimated input
# and output delays of the top ports of the FPGA design. By constraining with virtual
# clocks that match the waveform of the internal clock that opperates that port, the
# implementation (and synthesis?) are given the liberty to more accurately calculate
# the uncertainty timings at ports that talk with peripheral devices. This is taught
# in ALTERA training of the SDC constraints, and appears to function the same way with
# XILINX XDC constraints.
# create_clock -period 50.000 -name wiz_20mhz_virt_in -waveform {0.000 25.000}
# create_clock -period 50.000 -name wiz_20mhz_virt_out -waveform {0.000 25.000}
# create_clock -period 135.947 -name wiz_7_373mhz_virt_in -waveform {0.000 67.974}
# create_clock -period 135.947 -name wiz_7_373mhz_virt_out -waveform {0.000 67.974}
# The clock clk100hz_ssd has a floating-point or rounding error; or imprecision in the
# MMCM. Therefore, to match the generated clock waveform, the half-waveform ends
# at 49999.797 ns instead of 50000.000 ns.
# create_clock -period 99999.594 -name VIRTUAL_clk100hz_ssd -waveform {0.000 49999.797}

# The following are scaled input and output delays of the top-level ports of the design.
# The waveform that was calculated for determining the input and output delays as
# estimated values (rather than datasheet calculations) is taken from the Xilinx
# video on constraining FPGA timing: "Using the Vivado Timing Constraint Wizard".
# To determine more precise delay constraints requires collaboration between the
# board designer and the FPGA designer.

## Switches, Buttons
## The inpout of two-position switches and buttons is synchronized into the design
## at the MMCM 20 MHz clock. A virtual clock is used to allow the tool to automatically
## compute jitter and other metrics.
##
# Rising Edge System Synchronous Inputs
#
# A Single Data Rate (SDR) System Synchronous interface is
# an interface where the external device and the FPGA use
# the same clock, and a new data is captured one clock cycle
# after being launched
#
# input      __________            __________
# clock   __|          |__________|          |__
#           |
#           |------> (tco_min+trce_dly_min)
#           |------------> (tco_max+trce_dly_max)
#         __________      ________________    
# data    __________XXXXXX_____ Data _____XXXXXXX
#
# set input_clock     wiz_20mhz_virt_in;   # Name of input clock
# set tco_max         30.000;          # Maximum clock to out delay (external device)
# set tco_min         20.000;          # Minimum clock to out delay (external device)
# set trce_dly_max    0.400;          # Maximum board trace delay
# set trce_dly_min    0.200;          # Minimum board trace delay
# ## Buttons, Switches
# set input_ports     {ei_sw0 ei_sw1 ei_sw2 ei_sw3 ei_btn0 ei_btn1 ei_btn2 ei_btn3};  # List of input ports

# # Input Delay Constraint
# set_input_delay -clock $input_clock -max [expr $tco_max + $trce_dly_max] [get_ports $input_ports];
# set_input_delay -clock $input_clock -min [expr $tco_min + $trce_dly_min] [get_ports $input_ports];

## RGB LEDs and Basic LEDs
## The output of LEDs is synchronized out of the design at the MMCM 20 MHz clock.
## A virtual clock is used to allow the tool to automatically compute jitter and other metrics.
##
# Rising Edge System Synchronous Outputs 
#
# A System Synchronous design interface is a clocking technique in which the same 
# active-edge of a system clock is used for both the source and destination device. 
#
# dest        __________            __________
# clk    ____|          |__________|
#                                  |
#     (trce_dly_max+tsu) <---------|
#             (trce_dly_min-thd) <-|
#                        __    __
# data   XXXXXXXXXXXXXXXX__DATA__XXXXXXXXXXXXX
#
# set destination_clock wiz_20mhz_virt_out;     # Name of destination clock
# set tsu               5.600;            # Destination device setup time requirement
# set thd               0.900;            # Destination device hold time requirement
# set trce_dly_max      0.400;            # Maximum board trace delay
# set trce_dly_min      0.200;            # Minimum board trace delay
# set output_ports      {eo_led0_b eo_led0_g eo_led0_r eo_led1_b eo_led1_g eo_led1_r eo_led2 eo_led3 eo_led4 eo_led5};   # List of output ports

# # Output Delay Constraint
# set_output_delay -clock $destination_clock -max [expr $trce_dly_max + $tsu] [get_ports $output_ports];
# set_output_delay -clock $destination_clock -min [expr $trce_dly_min - $thd] [get_ports $output_ports];

## Pmod Header JA - inputs
## The inputs of PMOD ACL2 are all synchronized into the design at the 20 MHz MMCM clock.
## A virtual clock is used to allow the tool to automatically compute jitter and other metrics.
#
# Rising Edge System Synchronous Inputs
#
# A Single Data Rate (SDR) System Synchronous interface is
# an interface where the external device and the FPGA use
# the same clock, and a new data is captured one clock cycle
# after being launched
#
# input      __________            __________
# clock   __|          |__________|          |__
#           |
#           |------> (tco_min+trce_dly_min)
#           |------------> (tco_max+trce_dly_max)
#         __________      ________________    
# data    __________XXXXXX_____ Data _____XXXXXXX
#
# set input_clock     wiz_20mhz_virt_in;   # Name of input clock
# set tco_max         30.000;          # Maximum clock to out delay (external device)
# set tco_min         20.000;          # Minimum clock to out delay (external device)
# set trce_dly_max    0.400;          # Maximum board trace delay
# set trce_dly_min    0.200;          # Minimum board trace delay
# set input_ports     {ei_pmod_acl2_cipo ei_pmod_acl2_int1 ei_pmod_acl2_int2};  # List of input ports

# # Input Delay Constraint
# set_input_delay -clock $input_clock -max [expr $tco_max + $trce_dly_max] [get_ports $input_ports];
# set_input_delay -clock $input_clock -min [expr $tco_min + $trce_dly_min] [get_ports $input_ports];

## Pmod Header JA - outputs
## The output of PMOD ACL2 at SPI is synchronized out of the design at the MMCM 20 MHz clock.
## A virtual clock is used to allow the tool to automatically compute jitter and other metrics.
# Rising Edge System Synchronous Outputs 
#
# A System Synchronous design interface is a clocking technique in which the same 
# active-edge of a system clock is used for both the source and destination device. 
#
# dest        __________            __________
# clk    ____|          |__________|
#                                  |
#     (trce_dly_max+tsu) <---------|
#             (trce_dly_min-thd) <-|
#                        __    __
# data   XXXXXXXXXXXXXXXX__DATA__XXXXXXXXXXXXX
#

# set destination_clock wiz_20mhz_virt_out;     # Name of destination clock
# set tsu               5.600;            # Destination device setup time requirement
# set thd               0.900;            # Destination device hold time requirement
# set trce_dly_max      0.400;            # Maximum board trace delay
# set trce_dly_min      0.200;            # Minimum board trace delay
# set output_ports      {eo_pmod_acl2_copi eo_pmod_acl2_csn eo_pmod_acl2_sck};   # List of output ports

# # Output Delay Constraint
# set_output_delay -clock $destination_clock -max [expr $trce_dly_max + $tsu] [get_ports $output_ports];
# set_output_delay -clock $destination_clock -min [expr $trce_dly_min - $thd] [get_ports $output_ports];

## Pmod Header JB - inputs
## The inpout of full duplex SPI bus with the PMOD CLS peripheral is synchronized into
## the design at the MMCM 20 MHz clock. A virtual clock is used to allow the tool to
## automatically compute jitter and other metrics. This input is declared (unwired)
## in the RTL but is not used for writing characters to the LCD.
#
# Rising Edge System Synchronous Inputs
#
# A Single Data Rate (SDR) System Synchronous interface is
# an interface where the external device and the FPGA use
# the same clock, and a new data is captured one clock cycle
# after being launched
#
# input      __________            __________
# clock   __|          |__________|          |__
#           |
#           |------> (tco_min+trce_dly_min)
#           |------------> (tco_max+trce_dly_max)
#         __________      ________________    
# data    __________XXXXXX_____ Data _____XXXXXXX
#
# set input_clock     wiz_20mhz_virt_in;   # Name of input clock
# set tco_max         30.000;          # Maximum clock to out delay (external device)
# set tco_min         20.000;          # Minimum clock to out delay (external device)
# set trce_dly_max    0.400;          # Maximum board trace delay
# set trce_dly_min    0.200;          # Minimum board trace delay
# set input_ports     {ei_pmod_cls_dq1};  # List of input ports

# # Input Delay Constraint
# set_input_delay -clock $input_clock -max [expr $tco_max + $trce_dly_max] [get_ports $input_ports];
# set_input_delay -clock $input_clock -min [expr $tco_min + $trce_dly_min] [get_ports $input_ports];

## Pmod Header JB - outputs
## The output of PMOD CLS at SPI is synchronized into the design at the MMCM 20 MHz clock.
## A virtual clock is used to allow the tool to automatically compute jitter and other metrics.
# Rising Edge System Synchronous Outputs 
#
# A System Synchronous design interface is a clocking technique in which the same 
# active-edge of a system clock is used for both the source and destination device. 
#
# dest        __________            __________
# clk    ____|          |__________|
#                                  |
#     (trce_dly_max+tsu) <---------|
#             (trce_dly_min-thd) <-|
#                        __    __
# data   XXXXXXXXXXXXXXXX__DATA__XXXXXXXXXXXXX
#
# set destination_clock wiz_20mhz_virt_out; # Name of destination clock
# set tsu               5.600;           # Destination device setup time requirement
# set thd               0.900;            # Destination device hold time requirement
# set trce_dly_max      0.400;            # Maximum board trace delay
# set trce_dly_min      0.200;            # Minimum board trace delay
# set output_ports      {eo_pmod_cls_csn eo_pmod_cls_dq0 eo_pmod_cls_sck};   # List of output ports

# # Output Delay Constraint
# set_output_delay -clock $destination_clock -max [expr $trce_dly_max + $tsu] [get_ports $output_ports];
# set_output_delay -clock $destination_clock -min [expr $trce_dly_min - $thd] [get_ports $output_ports];

## Pmod Header JC - unused
#

## Pmod Header JD
# Rising Edge System Synchronous Outputs 
#
# A System Synchronous design interface is a clocking technique in which the same 
# active-edge of a system clock is used for both the source and destination device. 
#
# dest        __________            __________
# clk    ____|          |__________|
#                                  |
#     (trce_dly_max+tsu) <---------|
#             (trce_dly_min-thd) <-|
#                        __    __
# data   XXXXXXXXXXXXXXXX__DATA__XXXXXXXXXXXXX
#
# set destination_clock VIRTUAL_clk100hz_ssd; # Name of destination clock
# set tsu               23.600;           # Destination device setup time requirement
# set thd               3.000;            # Destination device hold time requirement
# set trce_dly_max      0.400;            # Maximum board trace delay
# set trce_dly_min      0.200;            # Minimum board trace delay
# set output_ports      {eo_ssd_pmod0[*]};   # List of output ports

# # Output Delay Constraint
# set_output_delay -clock $destination_clock -max [expr $trce_dly_max + $tsu] [get_ports $output_ports];
# set_output_delay -clock $destination_clock -min [expr $trce_dly_min - $thd] [get_ports $output_ports];

## USB-UART Interface
## The input of UART is disconnected, but would be sampled at
## division of the 7.373 MHz MMCM clock.
## The output of TX ONLY is synchronized out of the design at the MMCM 7.373 MHz clock.
## A virtual clock is used to allow the tool to automatically compute jitter and other metrics.
# Rising Edge System Synchronous Outputs 
#
# A System Synchronous design interface is a clocking technique in which the same 
# active-edge of a system clock is used for both the source and destination device. 
#
# dest        __________            __________
# clk    ____|          |__________|
#                                  |
#     (trce_dly_max+tsu) <---------|
#             (trce_dly_min-thd) <-|
#                        __    __
# data   XXXXXXXXXXXXXXXX__DATA__XXXXXXXXXXXXX
#

# set destination_clock wiz_7_373mhz_virt_out;     # Name of destination clock
# set tsu               14.100;           # Destination device setup time requirement
# set thd               2.600;            # Destination device hold time requirement
# set trce_dly_max      0.400;            # Maximum board trace delay
# set trce_dly_min      0.200;            # Minimum board trace delay
# set output_ports      {eo_uart_tx};   # List of output ports

# # Output Delay Constraint
# set_output_delay -clock $destination_clock -max [expr $trce_dly_max + $tsu] [get_ports $output_ports];
# set_output_delay -clock $destination_clock -min [expr $trce_dly_min - $thd] [get_ports $output_ports];

#set_input_delay -clock [get_clocks wiz_7_373mhz_virt_in] -max 54.253 [get_ports {ei_uart_rx}];
#set_input_delay -clock [get_clocks wiz_7_373mhz_virt_in] -min 13.563 [get_ports {ei_uart_rx}];

## Misc. ChipKit Ports
# The input delay is ignored for port i_resetn as it later set as a false path.
# However, to turn off thw input delay warning, the input delay is still set here.
# set_input_delay -clock [get_clocks wiz_20mhz_virt_in] -min -add_delay 20.200 [get_ports i_resetn]
# set_input_delay -clock [get_clocks wiz_20mhz_virt_in] -max -add_delay 30.400 [get_ports i_resetn]
# set_false_path -from [get_ports i_resetn] -to [all_registers]

## Internal asynchronous items requiring false_path
# set_false_path -to [get_pins u_uart_tx_only/u_fifo_uart_tx_0/bl.fifo_18_inst_bl.fifo_18_bl/RST]
