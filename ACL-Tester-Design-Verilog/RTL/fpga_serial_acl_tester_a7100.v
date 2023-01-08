/*------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020-2023 Timothy Stotts
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
------------------------------------------------------------------------------*/
/**-----------------------------------------------------------------------------
-- \file fpga_serial_acl_tester_a7100.v
--
-- \brief A FPGA top-level design with the PMOD ACL2 custom driver.
-- The target board is the Digilent Inc. Arty-A7-100 with a
-- Xilinx Artix-7 100T part.
-- This tester operates the ADXL362 in one of multiple possible operational
-- modes for Accelerometer data capture. The PMOD CLS is used to display
-- formatted data for: X-Axis, Y-Axis, Z-Axis, Temperature. Color and basic LEDs
-- are used to display additional information, including Activity and Inactivity
-- motion detection. The PMOD SSD/7SD displays two numbers representing
-- the selected indexes of the two threshold presets used in PMOD ACL2 Linked
-- Mode.
------------------------------------------------------------------------------*/
//------------------------------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module fpga_serial_acl_tester_a7100 (
  // external clock and active-low reset
  CLK100MHZ, i_resetn,
  // PMOD ACL2 SPI bus 4-wire and two interrupt signals
  eo_pmod_acl2_sck, eo_pmod_acl2_csn, eo_pmod_acl2_copi, ei_pmod_acl2_cipo,
  ei_pmod_acl2_int1, ei_pmod_acl2_int2,
  // blue emitters of the multicolor LEDs
  eo_led0_b, eo_led1_b, eo_led2_b, eo_led3_b,
  // red emitters of the multicolor LEDs
  eo_led0_r, eo_led1_r, eo_led2_r, eo_led3_r,
  // green emitters of the multicolor LEDs
  eo_led0_g, eo_led1_g, eo_led2_g, eo_led3_g,
  // green emitters of the basic LEDs
  eo_led4, eo_led5, eo_led6, eo_led7,
  // four switches
  ei_sw0, ei_sw1, ei_sw2, ei_sw3,
  // four buttons
  ei_btn0, ei_btn1, ei_btn2, ei_btn3,
  // PMOD CLS SPI bus 4-wire
  eo_pmod_cls_csn, eo_pmod_cls_sck, eo_pmod_cls_dq0,
  ei_pmod_cls_dq1,
  // Arty A7-100T UART TX and RX signals
  eo_uart_tx, ei_uart_rx,
  // PMOD 7SD direct GPIO
  eo_ssd_pmod0);

// Disable or enable fast FSM delays for simulation instead of implementation.
parameter integer parm_fast_simulation = 0;

input wire CLK100MHZ;
input wire i_resetn;

output wire eo_pmod_acl2_sck;
output wire eo_pmod_acl2_csn;
output wire eo_pmod_acl2_copi;
input wire ei_pmod_acl2_cipo;
input wire ei_pmod_acl2_int1;
input wire ei_pmod_acl2_int2;

output wire eo_led0_b;
output wire eo_led1_b;
output wire eo_led2_b;
output wire eo_led3_b;

output wire eo_led0_r;
output wire eo_led1_r;
output wire eo_led2_r;
output wire eo_led3_r;

output wire eo_led0_g;
output wire eo_led1_g;
output wire eo_led2_g;
output wire eo_led3_g;

output wire eo_led4;
output wire eo_led5;
output wire eo_led6;
output wire eo_led7;

input wire ei_sw0;
input wire ei_sw1;
input wire ei_sw2;
input wire ei_sw3;

input wire ei_btn0;
input wire ei_btn1;
input wire ei_btn2;
input wire ei_btn3;

output wire eo_pmod_cls_csn;
output wire eo_pmod_cls_sck;
output wire eo_pmod_cls_dq0;
input wire ei_pmod_cls_dq1;

output wire eo_uart_tx;
input wire ei_uart_rx;

output wire [7:0] eo_ssd_pmod0;

//Part 2: Declarations----------------------------------------------------------
// Main clock frequency in Hz
localparam integer c_FCLK = 20000000;

// MMCM and System Reset signals
wire s_mmcm_locked;
wire s_clk_20mhz;
wire s_rst_20mhz;
wire s_clk_7_37mhz;
wire s_rst_7_37mhz;
wire s_ce_2_5mhz;

// Definitions of the Standard SPI driver to pass to the ACL2 and CLS drivers
`define c_stand_spi_tx_fifo_count_bits 5
`define c_stand_spi_rx_fifo_count_bits 5
`define c_stand_spi_wait_count_bits 2

// Tri-state connectivity with the PMOD ACL2.
wire so_pmod_acl2_sck_o;
wire so_pmod_acl2_sck_t;
wire so_pmod_acl2_csn_o;
wire so_pmod_acl2_csn_t;
wire so_pmod_acl2_copi_o;
wire so_pmod_acl2_copi_t;

// Data and indications to be displayed on the LEDs and CLS.
wire [7:0] s_acl2_reg_status;
wire s_acl2_reg_status_activity_stretched;
wire s_acl2_reg_status_inactivity_stretched;
wire [63:0] s_hex_3axis_temp_measurements_final;
wire s_hex_3axis_temp_measurements_valid;
reg [63:0] s_hex_3axis_temp_measurements_display;
wire s_reading_inactive;

// Command to Operating Mode variables for the Tester FSM.
wire s_acl2_command_ready;
wire s_acl2_cmd_init_linked_mode;
wire s_acl2_cmd_start_linked_mode;
wire s_acl2_cmd_init_measur_mode;
wire s_acl2_cmd_start_measur_mode;
wire s_acl2_cmd_soft_reset_acl2;

// Tester FSM general outputs that translate to LED color display.
wire s_active_init_display;
wire s_active_run_display;
wire s_mode_is_measur;
wire s_mode_is_linked;

// switch inputs debounced
wire [3:0] si_switches;
wire [3:0] s_sw_deb;

// button inputs debounced
wire [3:0] si_buttons;
wire [3:0] s_btn_deb;

// Connections and variables for controlling the PMOD CLS custom driver.
wire s_cls_command_ready;
wire s_cls_wr_clear_display;
wire s_cls_wr_text_line1;
wire s_cls_wr_text_line2;
reg [(16*8-1):0] s_cls_txt_ascii_line1;
reg [(16*8-1):0] s_cls_txt_ascii_line2;
wire s_cls_feed_is_idle;

// Signals for text and data ASCII lines
wire [(16*8-1):0] s_adxl_dat_ascii_line1;
wire [(16*8-1):0] s_adxl_dat_ascii_line2;
wire [(16*8-1):0] s_adxl_txt_ascii_line1;
wire [(16*8-1):0] s_adxl_txt_ascii_line2;

// Connections for inferring tri-state buffer for CLS SPI bus outputs.
wire so_pmod_cls_sck_o;
wire so_pmod_cls_sck_t;
wire so_pmod_cls_csn_o;
wire so_pmod_cls_csn_t;
wire so_pmod_cls_copi_o;
wire so_pmod_cls_copi_t;

// Extra MMCM signals for full port map to the MMCM primitive, where
// these signals will remain disconnected.
wire s_clk_ignore_clk0b;
wire s_clk_ignore_clk1b;
wire s_clk_ignore_clk2;
wire s_clk_ignore_clk2b;
wire s_clk_ignore_clk3;
wire s_clk_ignore_clk3b;
wire s_clk_ignore_clk4;
wire s_clk_ignore_clk5;
wire s_clk_ignore_clk6;
wire s_clk_ignore_clkfboutb;
// Extra MMCM signals for full port map to the MMCM primitive, where
// these signals are connected.
wire s_clk_clkfbout;
wire s_clk_pwrdwn;
wire s_clk_resetin;

// Color palette signals to connect \ref led_palette_pulser to
// \ref led_pwm_driver .
wire [(4*8-1):0] s_color_led_red_value;
wire [(4*8-1):0] s_color_led_green_value;
wire [(4*8-1):0] s_color_led_blue_value;
wire [(4*8-1):0] s_basic_led_lumin_value;

// UART TX signals to connect \ref uart_tx_only and \ref uart_tx_feed
reg [(34*8-1):0] s_uart_dat_ascii_line;
wire s_uart_tx_go;
wire [7:0] s_uart_txdata;
wire s_uart_txvalid;
wire s_uart_txready;

// Values for display on the Pmod SSD/7SD
wire [3:0] s_thresh_value0;
wire [3:0] s_thresh_value1;

//Part 3: Statements------------------------------------------------------------
assign s_clk_pwrdwn = 1'b0;
assign s_clk_resetin = (~i_resetn);

// MMCME2_BASE: Base Mixed Mode Clock Manager
//              Artix-7
// Xilinx HDL Language Template, version 2019.1

MMCME2_BASE #(
  .BANDWIDTH("OPTIMIZED"),   // Jitter programming (OPTIMIZED, HIGH, LOW)
  .CLKFBOUT_MULT_F(36.125),  // Multiply value for all CLKOUT (2.000-64.000).
  .CLKFBOUT_PHASE(0.0),      // Phase offset in degrees of CLKFB (-360.000-360.000).
  .CLKIN1_PERIOD(10.0),      // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
  // CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
  .CLKOUT1_DIVIDE(98),
  .CLKOUT2_DIVIDE(1),
  .CLKOUT3_DIVIDE(1),
  .CLKOUT4_DIVIDE(1),
  .CLKOUT5_DIVIDE(1),
  .CLKOUT6_DIVIDE(1),
  .CLKOUT0_DIVIDE_F(36.125),  // Divide amount for CLKOUT0 (1.000-128.000).
  // CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
  .CLKOUT0_DUTY_CYCLE(0.5),
  .CLKOUT1_DUTY_CYCLE(0.5),
  .CLKOUT2_DUTY_CYCLE(0.5),
  .CLKOUT3_DUTY_CYCLE(0.5),
  .CLKOUT4_DUTY_CYCLE(0.5),
  .CLKOUT5_DUTY_CYCLE(0.5),
  .CLKOUT6_DUTY_CYCLE(0.5),
  // CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
  .CLKOUT0_PHASE(0.0),
  .CLKOUT1_PHASE(0.0),
  .CLKOUT2_PHASE(0.0),
  .CLKOUT3_PHASE(0.0),
  .CLKOUT4_PHASE(0.0),
  .CLKOUT5_PHASE(0.0),
  .CLKOUT6_PHASE(0.0),
  .CLKOUT4_CASCADE("FALSE"), // Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
  .DIVCLK_DIVIDE(5),         // Master division value (1-106)
  .REF_JITTER1(0.010),       // Reference input jitter in UI (0.000-0.999).
  .STARTUP_WAIT("FALSE")     // Delays DONE until MMCM is locked (FALSE, TRUE)
)
MMCME2_BASE_inst (
  // Clock Outputs: 1-bit (each) output: User configurable clock outputs
  .CLKOUT0(s_clk_20mhz),              // 1-bit output: CLKOUT0
  .CLKOUT0B(s_clk_ignore_clk0b),      // 1-bit output: Inverted CLKOUT0
  .CLKOUT1(s_clk_7_37mhz),            // 1-bit output: CLKOUT1
  .CLKOUT1B(s_clk_ignore_clk1b),      // 1-bit output: Inverted CLKOUT1
  .CLKOUT2(s_clk_ignore_clk2),        // 1-bit output: CLKOUT2
  .CLKOUT2B(s_clk_ignore_clk2b),      // 1-bit output: Inverted CLKOUT2
  .CLKOUT3(s_clk_ignore_clk3),        // 1-bit output: CLKOUT3
  .CLKOUT3B(s_clk_ignore_clk3b),      // 1-bit output: Inverted CLKOUT3
  .CLKOUT4(s_clk_ignore_clk4),        // 1-bit output: CLKOUT4
  .CLKOUT5(s_clk_ignore_clk5),        // 1-bit output: CLKOUT5
  .CLKOUT6(s_clk_ignore_clk6),        // 1-bit output: CLKOUT6
  // Feedback Clocks: 1-bit (each) output: Clock feedback ports
  .CLKFBOUT(s_clk_clkfbout),          // 1-bit output: Feedback clock
  .CLKFBOUTB(s_clk_ignore_clkfboutb), // 1-bit output: Inverted CLKFBOUT
  // Status Ports: 1-bit (each) output: MMCM status ports
  .LOCKED(s_mmcm_locked),             // 1-bit output: LOCK
  // Clock Inputs: 1-bit (each) input: Clock input
  .CLKIN1(CLK100MHZ),                 // 1-bit input: Clock
  // Control Ports: 1-bit (each) input: MMCM control ports
  .PWRDWN(s_clk_pwrdwn),              // 1-bit input: Power-down
  .RST(s_clk_resetin),                // 1-bit input: Reset
  // Feedback Clocks: 1-bit (each) input: Clock feedback ports
  .CLKFBIN(s_clk_clkfbout)            // 1-bit input: Feedback clock
);

// End of MMCME2_BASE_inst instantiation

// Reset Synchronization for 20 MHz clock.
arty_reset_synchronizer #() u_reset_synch_20mhz(
  .i_clk_mhz(s_clk_20mhz),
  .i_rstn_global(i_resetn),
  .o_rst_mhz(s_rst_20mhz)
  );

// Reset Synchronization for 7.37 MHz clock.
arty_reset_synchronizer #() u_reset_synch_7_37mhz (
  .i_clk_mhz(s_clk_7_37mhz),
  .i_rstn_global(i_resetn),
  .o_rst_mhz(s_rst_7_37mhz)
  );

// 4x spi clock enable divider for PMOD CLS SCK output. No
// generated clock constraint. The 20 MHz clock is divided
// down to 2.5 MHz; and later divided down to 625 KHz on
// the PMOD CLS bus.
clock_enable_divider #(
  .par_ce_divisor(8)
  ) u_2_5mhz_ce_divider (
  .o_ce_div(s_ce_2_5mhz),
  .i_clk_mhz(s_clk_20mhz),
  .i_rst_mhz(s_rst_20mhz),
  .i_ce_mhz(1'b1));

// Synchronize and debounce the four input switches on the Arty A7 to be
// debounced and exclusive of each other (zeros if more than one
// selected at the same time).
assign si_switches = {ei_sw3, ei_sw2, ei_sw1, ei_sw0};

multi_input_debounce #(
  .FCLK(c_FCLK)
  ) u_switches_deb_0123 (
    .i_clk_mhz(s_clk_20mhz),
    .i_rst_mhz(s_rst_20mhz),
    .ei_buttons(si_switches),
    .o_btns_deb(s_sw_deb)
    );

// Synchronize and debounce the four input buttons on the Arty A7 to be
// debounced and exclusive of each other (zeros if more than one
// selected at the same time).
assign si_buttons = {ei_btn3, ei_btn2, ei_btn1, ei_btn0};

multi_input_debounce #(
  .FCLK(c_FCLK)
  ) u_buttons_deb_0123 (
    .i_clk_mhz(s_clk_20mhz),
    .i_rst_mhz(s_rst_20mhz),
    .ei_buttons(si_buttons),
    .o_btns_deb(s_btn_deb)
    );

// LED PWM driver for color-mixed LED driving with variable intensity.
led_pwm_driver #(
    .parm_color_led_count(4),
    .parm_basic_led_count(4),
    .parm_FCLK(c_FCLK),
    .parm_pwm_period_milliseconds(10)
    ) u_led_pwm_driver (
    .i_clk(s_clk_20mhz),
    .i_srst(s_rst_20mhz),
    .i_color_led_red_value(s_color_led_red_value),
    .i_color_led_green_value(s_color_led_green_value),
    .i_color_led_blue_value(s_color_led_blue_value),
    .i_basic_led_lumin_value(s_basic_led_lumin_value),
    .eo_color_leds_r({eo_led3_r, eo_led2_r, eo_led1_r, eo_led0_r}),
    .eo_color_leds_g({eo_led3_g, eo_led2_g, eo_led1_g, eo_led0_g}),
    .eo_color_leds_b({eo_led3_b, eo_led2_b, eo_led1_b, eo_led0_b}),
    .eo_basic_leds_l({eo_led7, eo_led6, eo_led5, eo_led4})
    );

// LED palette pulser to manage the display of the LEDs
led_palette_pulser #(
  .parm_color_led_count(4),
  .parm_basic_led_count(4),
  .parm_FCLK(c_FCLK),
  .parm_adjustments_per_second(85)
  ) u_led_palette_pulser (
  .i_clk(s_clk_20mhz),
  .i_srst(s_rst_20mhz),
  .o_color_led_red_value(s_color_led_red_value),
  .o_color_led_green_value(s_color_led_green_value),
  .o_color_led_blue_value(s_color_led_blue_value),
  .o_basic_led_lumin_value(s_basic_led_lumin_value),
  .i_active_init_display(s_active_init_display),
  .i_active_run_display(s_active_run_display),
  .i_mode_is_measur_aux(s_mode_is_measur),
  .i_mode_is_linked_aux(s_mode_is_linked),
  .i_acl2_activity_stretched(s_acl2_reg_status_activity_stretched),
  .i_acl2_inactivity_stretched(s_acl2_reg_status_inactivity_stretched),
  .i_acl2_awake_status(s_acl2_reg_status[6]),
  .i_sw0_selected(s_sw_deb[0]),
  .i_sw1_selected(s_sw_deb[1])
  );

// Provide possible tri-state for later design revision for the PMOD ACL2 SPI
// output ports.
assign eo_pmod_acl2_sck = so_pmod_acl2_sck_t ? 1'bz : so_pmod_acl2_sck_o;
assign eo_pmod_acl2_csn = so_pmod_acl2_csn_t ? 1'bz : so_pmod_acl2_csn_o;
assign eo_pmod_acl2_copi = so_pmod_acl2_copi_t ? 1'bz : so_pmod_acl2_copi_o;

// PMOD ACL2 Custom Driver instance.
pmod_acl2_custom_driver #(
  .parm_fast_simulation(parm_fast_simulation),
  .FCLK(c_FCLK),
  .parm_ext_spi_clk_ratio(4),
  .parm_wait_cyc_bits(`c_stand_spi_wait_count_bits)
  ) u_pmod_acl2_custom_driver (
  .i_clk_20mhz(s_clk_20mhz),
  .i_rst_20mhz(s_rst_20mhz),
  .eo_sck_t(so_pmod_acl2_sck_t),
  .eo_sck_o(so_pmod_acl2_sck_o),
  .eo_csn_t(so_pmod_acl2_csn_t),
  .eo_csn_o(so_pmod_acl2_csn_o),
  .eo_copi_t(so_pmod_acl2_copi_t),
  .eo_copi_o(so_pmod_acl2_copi_o),
  .ei_cipo(ei_pmod_acl2_cipo),
  .ei_int1(ei_pmod_acl2_int1),
  .ei_int2(ei_pmod_acl2_int2),
  .o_command_ready(s_acl2_command_ready),
  .i_cmd_init_linked_mode(s_acl2_cmd_init_linked_mode),
  .i_cmd_start_linked_mode(s_acl2_cmd_start_linked_mode),
  .i_cmd_init_measur_mode(s_acl2_cmd_init_measur_mode),
  .i_cmd_start_measur_mode(s_acl2_cmd_start_measur_mode),
  .i_cmd_soft_reset_acl2(s_acl2_cmd_soft_reset_acl2),
  .o_data_3axis_temp(s_hex_3axis_temp_measurements_final),
  .o_data_valid(s_hex_3axis_temp_measurements_valid),
  .o_reg_status(s_acl2_reg_status),
  .i_btn_deb(s_btn_deb[1-:2]),
  .o_enum_active(s_thresh_value1),
  .o_enum_inactive(s_thresh_value0)
  );

// Tester FSM to operate the states of the Pmod ACL2 based on switch input
acl_tester_fsm #(
  ) u_acl_tester_fsm (
  .i_clk_20mhz(s_clk_20mhz),
  .i_rst_20mhz(s_rst_20mhz),
  .i_acl_command_ready(s_acl2_command_ready),
  .i_switches_debounced(s_sw_deb),
  .o_reading_inactive(s_reading_inactive),
  .o_active_init_display(s_active_init_display),
  .o_active_run_display(s_active_run_display),
  .o_mode_is_measur(s_mode_is_measur),
  .o_mode_is_linked(s_mode_is_linked),
  .o_acl_cmd_init_measur_mode(s_acl2_cmd_init_measur_mode),
  .o_acl_cmd_start_measur_mode(s_acl2_cmd_start_measur_mode),
  .o_acl_cmd_init_linked_mode(s_acl2_cmd_init_linked_mode),
  .o_acl_cmd_start_linked_mode(s_acl2_cmd_start_linked_mode),
  .o_acl_cmd_soft_reset(s_acl2_cmd_soft_reset_acl2)
  );

// Capture the latest measurement value on VALID pulse and when the display is
// idling in preparation of the next value to be displayed. When the display
// stops idling, then hold the value for display so that the display does not
// have its textual inputs changing while running the display update. This
// value capture also holds for the UART TX output of the values.
always @(posedge s_clk_20mhz)
begin: p_hold_measurements
  if (s_rst_20mhz) s_hex_3axis_temp_measurements_display <= 64'd0;
  else
    if (s_hex_3axis_temp_measurements_valid && s_cls_feed_is_idle) begin
      s_hex_3axis_temp_measurements_display <= s_hex_3axis_temp_measurements_final;
    end
end

// Stretch the Activity indication so it can be displayed as color LED 2.
pulse_stretcher_synch #(
  .par_T_stretch_bits(25),
  .par_T_stretch_val(c_FCLK)
  ) u_pulse_stretcher_activity (
    .o_y(s_acl2_reg_status_activity_stretched),
    .i_clk(s_clk_20mhz),
    .i_rst(s_rst_20mhz),
    .i_x(s_acl2_reg_status[4]));

// Stretch the Inactivity indication so it can be displayed as color LED 3.
pulse_stretcher_synch #(
  .par_T_stretch_bits(25),
  .par_T_stretch_val(c_FCLK)
  ) u_pulse_stretcher_inactivity (
    .o_y(s_acl2_reg_status_inactivity_stretched),
    .i_clk(s_clk_20mhz),
    .i_rst(s_rst_20mhz),
    .i_x(s_acl2_reg_status[5]));

// Tri-state outputs of PMOD CLS custom driver.
assign eo_pmod_cls_sck = so_pmod_cls_sck_t ? 1'bz : so_pmod_cls_sck_o;
assign eo_pmod_cls_csn = so_pmod_cls_csn_t ? 1'bz : so_pmod_cls_csn_o;
assign eo_pmod_cls_dq0 = so_pmod_cls_copi_t ? 1'bz : so_pmod_cls_copi_o;

// Instance of the PMOD CLS driver for 16x2 character LCD display for purposes
// of an output display.
pmod_cls_custom_driver #(
  .parm_fast_simulation(parm_fast_simulation),
  .FCLK(c_FCLK),
  .FCLK_ce(2500000),
  .parm_ext_spi_clk_ratio(32),
  .parm_wait_cyc_bits(`c_stand_spi_wait_count_bits)
  ) u_pmod_cls_custom_driver (
  .i_clk_20mhz(s_clk_20mhz),
  .i_rst_20mhz(s_rst_20mhz),
  .i_ce_2_5mhz(s_ce_2_5mhz),
  .eo_sck_t(so_pmod_cls_sck_t),
  .eo_sck_o(so_pmod_cls_sck_o),
  .eo_csn_t(so_pmod_cls_csn_t),
  .eo_csn_o(so_pmod_cls_csn_o),
  .eo_copi_t(so_pmod_cls_copi_t),
  .eo_copi_o(so_pmod_cls_copi_o),
  .ei_cipo(ei_pmod_cls_dq1),
  .o_command_ready(s_cls_command_ready),
  .i_cmd_wr_clear_display(s_cls_wr_clear_display),
  .i_cmd_wr_text_line1(s_cls_wr_text_line1),
  .i_cmd_wr_text_line2(s_cls_wr_text_line2),
  .i_dat_ascii_line1(s_cls_txt_ascii_line1),
  .i_dat_ascii_line2(s_cls_txt_ascii_line2));

// Select the text to display on the Pmod CLS based om whether button 3
// is or is not depressed.
always @(posedge s_clk_20mhz)
begin: p_reg_cls_line
  if (s_btn_deb == 4'b1000) begin
    s_cls_txt_ascii_line1 <= s_adxl_dat_ascii_line1;
    s_cls_txt_ascii_line2 <= s_adxl_dat_ascii_line2;
  end else begin
    s_cls_txt_ascii_line1 <= s_adxl_txt_ascii_line1;
    s_cls_txt_ascii_line2 <= s_adxl_txt_ascii_line2;
  end
end

// LCD Update FSM
lcd_text_feed #(
  .parm_fast_simulation(parm_fast_simulation)
  ) u_lcd_text_feed (
  .i_clk_20mhz(s_clk_20mhz),
  .i_rst_20mhz(s_rst_20mhz),
  .i_ce_2_5mhz(s_ce_2_5mhz),
  .i_lcd_command_ready(s_cls_command_ready),
  .o_lcd_wr_clear_display(s_cls_wr_clear_display),
  .o_lcd_wr_text_line1(s_cls_wr_text_line1),
  .o_lcd_wr_text_line2(s_cls_wr_text_line2),
  .o_lcd_feed_is_idle(s_cls_feed_is_idle)
  );

// Measurement Readings to ASCII conversion
adxl362_readings_to_ascii #(
  ) u_adxl362_readings_to_ascii (
    .i_3axis_temp(s_hex_3axis_temp_measurements_display),
    .i_reading_inactive(s_reading_inactive),
    .o_dat_ascii_line1(s_adxl_dat_ascii_line1),
    .o_dat_ascii_line2(s_adxl_dat_ascii_line2),
    .o_txt_ascii_line1(s_adxl_txt_ascii_line1),
    .o_txt_ascii_line2(s_adxl_txt_ascii_line2)
    );

// TX ONLY UART function to print the two lines of the PMOD CLS output as a
// single line on the dumb terminal, at the same rate as the PMOD CLS updates.
// Assembly of UART text line.

// Select the text to display on the UART Terminal based om whether button 2
// is or is not depressed.
always @(posedge s_clk_20mhz)
begin: p_reg_uart_line
  if (s_btn_deb == 4'b0100)
    s_uart_dat_ascii_line <= {s_adxl_txt_ascii_line1, s_adxl_txt_ascii_line2,
                8'h0D, 8'h0A};
  else
    s_uart_dat_ascii_line <= {s_adxl_dat_ascii_line1, s_adxl_dat_ascii_line2,
                8'h0D, 8'h0A};
end

assign s_uart_tx_go = s_cls_wr_clear_display;

uart_tx_only #(
  .BAUD(115200)
  ) u_uart_tx_only (
  .i_clk_20mhz  (s_clk_20mhz),
  .i_rst_20mhz  (s_rst_20mhz),
  .i_clk_7_37mhz(s_clk_7_37mhz),
  .i_rst_7_37mhz(s_rst_7_37mhz),
  .eo_uart_tx   (eo_uart_tx),
  .i_tx_data    (s_uart_txdata),
  .i_tx_valid   (s_uart_txvalid),
  .o_tx_ready   (s_uart_txready)
  );

uart_tx_feed #(
  ) u_uart_tx_feed (
  .i_clk_20mhz(s_clk_20mhz),
  .i_rst_20mhz(s_rst_20mhz),
  .o_tx_data(s_uart_txdata),
  .o_tx_valid(s_uart_txvalid),
  .i_tx_ready(s_uart_txready),
  .i_tx_go(s_uart_tx_go),
  .i_dat_ascii_line(s_uart_dat_ascii_line)
  );

// A single PMOD 7SD, two digit seven segment display, to display the index
// of Activity threshold preset and Inactivity threshold preset.
one_pmod_ssd_display #() u_one_pmod_ssd_display (
  .i_clk_20mhz(s_clk_20mhz),
  .i_rst_20mhz(s_rst_20mhz),
  .i_value0(s_thresh_value0),
  .i_value1(s_thresh_value1),
  .o_ssd_pmod0(eo_ssd_pmod0)
  );

endmodule
//------------------------------------------------------------------------------
