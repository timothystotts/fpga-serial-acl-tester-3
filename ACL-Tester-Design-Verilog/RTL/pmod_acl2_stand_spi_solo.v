/*------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020,2022 Timothy Stotts
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
-- \file pmod_acl2_stand_spi_solo.v
--
-- \brief A custom driver to operate the PMOD ACL2 accelerometer with ADXL362,
-- that relies upon \ref pmod_generic_spi_solo to implement the Standard SPI
-- interface.
--
-- \description TODO: review comments of this file's FSM.
------------------------------------------------------------------------------*/
//------------------------------------------------------------------------------
//Recursive Moore Machine
//Part 1: Module header:--------------------------------------------------------
module pmod_acl2_stand_spi_solo (
   // system clock and synchronous reset
   i_ext_spi_clk_x, i_srst, i_spi_ce_4x,
   // interrupt lines of the PMOD ACL2
   ei_int1, ei_int2,
   // system interface to the \ref pmod_generic_spi_solo module.
   o_go_stand, i_spi_idle, o_tx_len, o_wait_cyc, o_rx_len,
   // TX FIFO interface to the \ref pmod_generic_spi_solo module.
   o_tx_data, o_tx_enqueue, i_tx_ready,
   // RX FIFO interface to the \ref pmod_generic_spi_solo module.
   i_rx_data, o_rx_dequeue, i_rx_valid, i_rx_avail,
   // FPGA system interface to ACL2 operation
   o_command_ready,
   i_cmd_init_linked_mode,
   i_cmd_start_linked_mode,
   i_cmd_init_measur_mode,
   i_cmd_start_measur_mode,
   i_cmd_soft_reset_acl2,
   // measurement data streaming output of the accelerometer
   o_rd_data_stream, o_rd_data_byte_valid, o_rd_data_group_valid,
   // data status of accelerometer
   o_reg_status,
   // run-time dynamic configuration of Linked Mode
   i_tx_ax_cfg0_lm);

// Disable or enable fast FSM delays for simulation instead of implementation.
parameter integer parm_fast_simulation = 0;
// Actual frequency in Hz of \ref i_ext_spi_clk_4x
parameter integer FCLK = 20000000;
// LOG2 of the TX FIFO max count
parameter parm_tx_len_bits = 11;
// LOG2 of max Wait Cycles count between end of TX and start of RX
parameter parm_wait_cyc_bits = 2;
// LOG2 of the RX FIFO max count
parameter parm_rx_len_bits = 11;

input wire i_ext_spi_clk_x;
input wire i_srst;
input wire i_spi_ce_4x;

input wire ei_int1;
input wire ei_int2;

output reg o_go_stand;
input wire i_spi_idle;
output reg [(parm_tx_len_bits - 1):0] o_tx_len;
output reg [(parm_wait_cyc_bits - 1):0] o_wait_cyc;
output reg [(parm_rx_len_bits - 1):0] o_rx_len;

output reg [7:0] o_tx_data;
output reg o_tx_enqueue;
input wire i_tx_ready;

input wire [7:0] i_rx_data;
output reg o_rx_dequeue;
input wire i_rx_valid;
input wire i_rx_avail;

output reg o_command_ready;
input wire i_cmd_init_linked_mode;
input wire i_cmd_start_linked_mode;
input wire i_cmd_init_measur_mode;
input wire i_cmd_start_measur_mode;
input wire i_cmd_soft_reset_acl2;

output reg [7:0] o_rd_data_stream;
output reg o_rd_data_byte_valid;
output reg o_rd_data_group_valid;

output wire [7:0] o_reg_status;

input wire [7*8-1:0] i_tx_ax_cfg0_lm;

// Part 2: Declarations---------------------------------------------------------
// Timer signals and constants
`define c_drv_time_value_bits 24
// Boot time should be in hundreds of milliseconds as the ADXL362 lists on
// page 5 of datasheet Rev. F that the Power-Up to Standby time is
// 5 milliseconds typical, and does not list a maximum time.
// This constant can be overriden with a fast boot delay by passing a non-zero
// to the parameter \ref parm_fast_simulation .
localparam [(`c_drv_time_value_bits - 1):0] c_t_adxl362_boot =
   parm_fast_simulation ? (FCLK * 1 / 10000) : (FCLK * 100 / 1000);
localparam [(`c_drv_time_value_bits - 1):0] c_tmax = c_t_adxl362_boot - 1;

reg [(`c_drv_time_value_bits - 1):0] s_t;

// Driver FSM state declarations
`define c_drv_state_bits 6
localparam [(`c_drv_state_bits - 1):0] ST_DRV_BOOT0 = 0;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_IDLE0 = 1;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_INIT_LM = 2;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_INIT_MM = 3;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG0_CMD = 4;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG0_ADDR = 5;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG0_DATA = 6;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WAIT_AX_CFG0 = 7;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG1_CMD = 8;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG1_ADDR = 9;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG1_DATA = 10;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WAIT_AX_CFG1 = 11;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG2_CMD = 12;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG2_ADDR = 13;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG2_DATA = 14;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WAIT_AX_CFG2 = 15;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG3_CMD = 16;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG3_ADDR = 17;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG3_DATA = 18;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WAIT_AX_CFG3 = 19;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG4_CMD = 20;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG4_ADDR = 21;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG4_DATA = 22;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WAIT_AX_CFG4 = 23;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG5_CMD = 24;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG5_ADDR = 25;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WR_AX_CFG5_DATA = 26;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_WAIT_AX_CFG5 = 27;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_IDLE1 = 28;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_WAIT_DR_INT1 = 29;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_MEASU_CMD = 30;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_MEASU_ADDR = 31;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_MEASU_DATA = 32;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_WAIT0 = 33;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_CLEAR_MEASU_CMD = 34;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_CLEAR_MEASU_ADDR= 35;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_CLEAR_MEASU_DATA = 36;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_WAIT1 = 37;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_WAIT2 = 38;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_WAIT_AT_INT1 = 39;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_INACT0_CMD = 40;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_INACT0_ADDR = 41;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_INACT0_DATA = 42;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_WAIT3 = 43;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_CLEAR_AWAKE0_CMD = 44;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_CLEAR_AWAKE0_ADDR = 45;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_CLEAR_AWAKE0_DATA = 46;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_WAIT4 = 47;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_WAIT5 = 48;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_WAIT_AT_INT2 = 49;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_ACT0_CMD = 50;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_ACT0_ADDR = 51;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_ACT0_DATA = 52;

localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_WAIT6 = 53;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_CLEAR_AWAKE1_CMD = 54;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_CLEAR_AWAKE1_ADDR = 55;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_CLEAR_AWAKE1_DATA = 56;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_WAIT7 = 57;
localparam [(`c_drv_state_bits - 1):0] ST_DRV_READ_WAIT8 = 58;

localparam [(`c_drv_state_bits - 1):0]  ST_DRV_SOFTRESET_CMD = 59;
localparam [(`c_drv_state_bits - 1):0]  ST_DRV_SOFTRESET_ADDR = 60;
localparam [(`c_drv_state_bits - 1):0]  ST_DRV_SOFTRESET_DATA = 61;
localparam [(`c_drv_state_bits - 1):0]  ST_DRV_SOFTRESET_WAIT9 = 62;

// ADXL362 command bytes.
localparam [7:0] c_adxl362_cmd_write = 8'h0A;
localparam [7:0] c_adxl362_cmd_read = 8'h0B;
localparam [7:0] c_adxl362_cmd_fifo = 8'h0D;

// ADXL362 configurable register areas according to Applications section of the
// datasheeet: the starting address of these sections.
localparam [7:0] c_adxl362_addr_cfg0 = 8'h20;
localparam [7:0] c_adxl362_addr_cfg1 = 8'h27;
localparam [7:0] c_adxl362_addr_cfg2 = 8'h28;
localparam [7:0] c_adxl362_addr_cfg3 = 8'h2A;
localparam [7:0] c_adxl362_addr_cfg4 = 8'h2C;
localparam [7:0] c_adxl362_addr_cfg5 = 8'h2D;
localparam [7:0] c_adxl362_addr_8reg = 8'h0E;
localparam [7:0] c_adxl362_addr_stat = 8'h0B;
localparam [7:0] c_adxl362_addr_sr = 8'h1F;
localparam [7:0] c_adxl362_data_sr = 8'h52;

// Count of bytes to TX and count of bytes to RX, for each operation of the
// state machine.
localparam [(parm_tx_len_bits - 1):0] c_tx_ax_cfg0_length = 2 + 7;
localparam [(parm_tx_len_bits - 1):0] c_tx_ax_cfg1_length = 2 + 1;
localparam [(parm_tx_len_bits - 1):0] c_tx_ax_cfg2_length = 2 + 2;
localparam [(parm_tx_len_bits - 1):0] c_tx_ax_cfg3_length = 2 + 2;
localparam [(parm_tx_len_bits - 1):0] c_tx_ax_cfg4_length = 2 + 1;
localparam [(parm_tx_len_bits - 1):0] c_tx_ax_cfg5_length = 2 + 1;
localparam [(parm_tx_len_bits - 1):0] c_tx_ax_sr_length = 2 + 1;
localparam [(parm_tx_len_bits - 1):0] c_tx_ax_readmm_length = 2;
localparam [(parm_rx_len_bits - 1):0] c_rx_ax_readmm_length = 8;
localparam [(parm_tx_len_bits - 1):0] c_tx_ax_clearmm_length = 2;
localparam [(parm_rx_len_bits - 1):0] c_rx_ax_clearmm_length = 1;
localparam [(parm_tx_len_bits - 1):0] c_tx_ax_readlm_length = 2;
localparam [(parm_rx_len_bits - 1):0] c_rx_ax_readlm_length = 8;
localparam [(parm_tx_len_bits - 1):0] c_tx_ax_clearlm_length = 2;
localparam [(parm_rx_len_bits - 1):0] c_rx_ax_clearlm_length = 1;

// 0x20 : 0x26
localparam [((7 * 8) - 1):0] c_tx_ax_cfg0_lm =
   // THRESH_ACT_L, THRESH_ACT_H, TIME_ACT, THRESH_INACT_L, THRESH_INACT_H,
   // TIME_INACT_L, TIME_INACT_H
   {8'h20, 8'h00, 8'h64, 8'h1A, 8'h00,
    8'h64, 8'h00};

// 0x27
localparam [((1 * 8) - 1):0] c_tx_ax_cfg1_lm =
   // ACT_INACT_CTL
   8'b00011111;

// 0x28 : 0x29
localparam [((2 * 8) - 1):0] c_tx_ax_cfg2_lm =
   // FIFO_CONTROL, FIFO_SAMPLES
   {8'b00000000, 8'b00000000};

// 0x2A : 0x2B
localparam [((2 * 8) - 1):0] c_tx_ax_cfg3_lm =
   // INTMAP1, INTMAP2
   {8'h20, 8'h10};

// 0x2C
localparam [((1 * 8) - 1):0] c_tx_ax_cfg4_lm =
   // FILTER_CTL
   {8'b00010011};

// 0x2D
localparam [((1 * 8) - 1):0] c_tx_ax_cfg5_lm =
   // POWER_CTL
   {8'b00100010};

// 0x20 : 0x26
localparam [((7 * 8) - 1):0] c_tx_ax_cfg0_mm =
   // THRESH_ACT_L, THRESH_ACT_H, TIME_ACT, THRESH_INACT_L, THRESH_INACT_H,
   // TIME_INACT_L, TIME_INACT_H
   {8'h14, 8'h00, 8'h64, 8'h10, 8'h00,
    8'h64, 8'h00};

// 0x27
localparam [((1 * 8) - 1):0] c_tx_ax_cfg1_mm =
   // ACT_INACT_CTL
   8'b00000101;

// 0x28 : 0x29
localparam [((2 * 8) - 1):0] c_tx_ax_cfg2_mm =
   // FIFO_CONTROL, FIFO_SAMPLES
   {8'b00000000, 8'b00000000};

// 0x2A : 0x2B
localparam [((2 * 8) - 1):0] c_tx_ax_cfg3_mm =
   // INTMAP1, INTMAP2
   {8'h01, 8'h00};

// 0x2C
localparam [((1 * 8) - 1):0] c_tx_ax_cfg4_mm =
   // FILTER_CTL
   {8'b00010011};

// 0x2D
localparam [((1 * 8) - 1):0] c_tx_ax_cfg5_mm =
   // POWER_CTL
   {8'b00100010};


// Xilinx attributes for Auto encoding of the FSM and safe state is
// Default State.
(* fsm_encoding = "auto" *)
(* fsm_safe_state = "default_state" *)
reg [(`c_drv_state_bits - 1):0] s_acl2_drv_pr_state = ST_DRV_BOOT0;
reg [(`c_drv_state_bits - 1):0] s_acl2_drv_nx_state = ST_DRV_BOOT0;

// Auxiliary state machine registers for recursive state machine operation.
reg [((7 * 8) - 1):0] s_tx_ax_cfg0_val;
reg [((7 * 8) - 1):0] s_tx_ax_cfg0_aux;
reg [((1 * 8) - 1):0] s_tx_ax_cfg1_val;
reg [((1 * 8) - 1):0] s_tx_ax_cfg1_aux;
reg [((2 * 8) - 1):0] s_tx_ax_cfg2_val;
reg [((2 * 8) - 1):0] s_tx_ax_cfg2_aux;
reg [((2 * 8) - 1):0] s_tx_ax_cfg3_val;
reg [((2 * 8) - 1):0] s_tx_ax_cfg3_aux;
reg [((1 * 8) - 1):0] s_tx_ax_cfg4_val;
reg [((1 * 8) - 1):0] s_tx_ax_cfg4_aux;
reg [((1 * 8) - 1):0] s_tx_ax_cfg5_val;
reg [((1 * 8) - 1):0] s_tx_ax_cfg5_aux;
reg [7:0] s_byte_index_val;
reg [7:0] s_byte_index_aux;
reg [7:0] s_reg_status_val;
reg [7:0] s_reg_status_aux;

//Part 3: Statements------------------------------------------------------------
assign o_reg_status = s_reg_status_aux;

// Timer 1 (Strategy #1), for timing the boot wait for PMOD ACL2 communication
always @(posedge i_ext_spi_clk_x)
begin: p_timer_1
   if (i_srst) s_t <= 0;
   else
      if (i_spi_ce_4x)
         if (s_acl2_drv_pr_state != s_acl2_drv_nx_state) s_t <= 0;
         else if (s_t < c_tmax) s_t <= s_t + 1;
end

// FSM state register plus auxiliary registers, for propagating the next state
// as well as the next recursive auxiliary register value for use within
// one or more state combinatorial logic decisions.
always @(posedge i_ext_spi_clk_x)
begin: p_fsm_state_aux
   if (i_srst) begin
      s_acl2_drv_pr_state <= ST_DRV_BOOT0;

      s_tx_ax_cfg0_aux <= 56'h00000000000000;
      s_tx_ax_cfg1_aux <= 8'h00;
      s_tx_ax_cfg2_aux <= 16'h0000;
      s_tx_ax_cfg3_aux <= 16'h0000;
      s_tx_ax_cfg4_aux <= 8'h00;
      s_tx_ax_cfg5_aux <= 8'h00;
      s_byte_index_aux <= 0;
      s_reg_status_aux <= 8'b00;
   end else
      if (i_spi_ce_4x) begin
         s_acl2_drv_pr_state <= s_acl2_drv_nx_state;

         s_tx_ax_cfg0_aux <= s_tx_ax_cfg0_val;
         s_tx_ax_cfg1_aux <= s_tx_ax_cfg1_val;
         s_tx_ax_cfg2_aux <= s_tx_ax_cfg2_val;
         s_tx_ax_cfg3_aux <= s_tx_ax_cfg3_val;
         s_tx_ax_cfg4_aux <= s_tx_ax_cfg4_val;
         s_tx_ax_cfg5_aux <= s_tx_ax_cfg5_val;
         s_byte_index_aux <= s_byte_index_val;
         s_reg_status_aux <= s_reg_status_val;
      end
end

// FSM combinatorial logic providing multiple outputs, assigned in every state,
// as well as changes in auxiliary values, and calculation of the next FSM
// state. Refer to the FSM state machine drawings.
always @(s_acl2_drv_pr_state,
   s_tx_ax_cfg0_aux, s_tx_ax_cfg1_aux, s_tx_ax_cfg2_aux,
   s_tx_ax_cfg3_aux, s_tx_ax_cfg4_aux, s_tx_ax_cfg5_aux,
   s_byte_index_aux, s_reg_status_aux, ei_int1, ei_int2,
   i_cmd_start_measur_mode, i_cmd_start_linked_mode,
   i_cmd_init_measur_mode, i_cmd_init_linked_mode,
   i_cmd_soft_reset_acl2,
   i_tx_ready, i_rx_avail, i_rx_valid, i_rx_data,
   i_spi_idle, s_t,
   i_tx_ax_cfg0_lm
   )
begin: p_fsm_comb
   // default values were not set here with blocking assignment,
   // because it is anticipated to do so would cause potential glitches
   // in the combinatorial logic. blocking assignment is used instead
   // of non-blocking assignment only because that is a prerequisite
   // for Xilinx Vivado to synthesize a fully combinatorial logic
   // block. outputs and auxiliary registers must be assigned in
   // every case of the FSM state, including a default: clause for
   // unlisted binary state values to default to the initial state.
   case (s_acl2_drv_pr_state)
      ST_DRV_INIT_LM: begin
         // Load auxiliary registers with Linked Mode configuration.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = i_tx_ax_cfg0_lm;
         s_tx_ax_cfg1_val = c_tx_ax_cfg1_lm;
         s_tx_ax_cfg2_val = c_tx_ax_cfg2_lm;
         s_tx_ax_cfg3_val = c_tx_ax_cfg3_lm;
         s_tx_ax_cfg4_val = c_tx_ax_cfg4_lm;
         s_tx_ax_cfg5_val = c_tx_ax_cfg5_lm;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG0_CMD;
      end

      ST_DRV_INIT_MM: begin
         // Load auxiliary registers with Measurement Mode configuration.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = c_tx_ax_cfg0_mm;
         s_tx_ax_cfg1_val = c_tx_ax_cfg1_mm;
         s_tx_ax_cfg2_val = c_tx_ax_cfg2_mm;
         s_tx_ax_cfg3_val = c_tx_ax_cfg3_mm;
         s_tx_ax_cfg4_val = c_tx_ax_cfg4_mm;
         s_tx_ax_cfg5_val = c_tx_ax_cfg5_mm;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG0_CMD;
      end

      ST_DRV_WR_AX_CFG0_CMD: begin
         // Load first byte, command WRITE, to TX FIFO.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_write;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg0_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready) begin
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG0_ADDR;
         end else begin
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG0_CMD;
         end
      end

      ST_DRV_WR_AX_CFG0_ADDR: begin
         // Load second byte, starting address for Configuration 0 byte
         // sequence, to TX FIFO
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_cfg0;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg0_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = (c_tx_ax_cfg0_length - 2);
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready) begin
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG0_DATA;
         end else begin
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG0_ADDR;
         end
      end

      ST_DRV_WR_AX_CFG0_DATA: begin
         // Load \ref c_tx_ax_cfg0_length - 2 count of register WRITE data bytes,
         // and then trigger the Standard SPI operation.
         o_command_ready = 1'b0;
         o_tx_len = c_tx_ax_cfg0_length;
         o_tx_data = s_tx_ax_cfg0_aux[((s_byte_index_aux * 8) - 1) -: 8];
         o_tx_enqueue = i_tx_ready;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = (s_byte_index_aux > 1) ? 1'b0 : (i_tx_ready ? 1'b1 : 1'b0);
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = (i_tx_ready) ? (s_byte_index_aux - 1) : (s_byte_index_aux);
         s_reg_status_val = s_reg_status_aux;

         if ((i_tx_ready == 1'b1) && (s_byte_index_aux <= 1))
            s_acl2_drv_nx_state = ST_DRV_WAIT_AX_CFG0;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG0_DATA;
      end

      ST_DRV_WAIT_AX_CFG0: begin
         // Wait for the SPI operation to complete and return to IDLE
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_cfg0_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG1_CMD;
         else s_acl2_drv_nx_state = ST_DRV_WAIT_AX_CFG0;
      end

      ST_DRV_WR_AX_CFG1_CMD: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_write;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg1_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG1_ADDR;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG1_CMD;
      end

      ST_DRV_WR_AX_CFG1_ADDR: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_cfg1;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg1_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = (c_tx_ax_cfg1_length - 2);
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG1_DATA;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG1_ADDR;
      end

      ST_DRV_WR_AX_CFG1_DATA: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = s_tx_ax_cfg1_aux[((s_byte_index_aux * 8) - 1) -: 8];
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg1_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = (s_byte_index_aux > 1) ? 1'b0 : (i_tx_ready ? 1'b1 : 1'b0);
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = i_tx_ready ? (s_byte_index_aux - 1) : s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if ((i_tx_ready == 1'b1)  && (s_byte_index_aux <= 1))
            s_acl2_drv_nx_state = ST_DRV_WAIT_AX_CFG1;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG1_DATA;
      end

      ST_DRV_WAIT_AX_CFG1: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_cfg1_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG2_CMD;
         else s_acl2_drv_nx_state = ST_DRV_WAIT_AX_CFG1;
      end

      ST_DRV_WR_AX_CFG2_CMD: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_write;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg2_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG2_ADDR;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG2_CMD;
      end

      ST_DRV_WR_AX_CFG2_ADDR: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_cfg2;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg2_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = (c_tx_ax_cfg2_length - 2);
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG2_DATA;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG2_ADDR;
      end

      ST_DRV_WR_AX_CFG2_DATA: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_len = c_tx_ax_cfg2_length;
         o_tx_data = s_tx_ax_cfg2_aux[((s_byte_index_aux * 8) - 1) -: 8];
         o_tx_enqueue = i_tx_ready;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = (s_byte_index_aux > 1) ? 1'b0 : (i_tx_ready ? 1'b1 : 1'b0);
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = i_tx_ready ? (s_byte_index_aux - 1) : s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            if (s_byte_index_aux > 1)
               s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG2_DATA;
            else
               s_acl2_drv_nx_state = ST_DRV_WAIT_AX_CFG2;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG2_DATA;
      end

      ST_DRV_WAIT_AX_CFG2: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_cfg2_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG3_CMD;
         else s_acl2_drv_nx_state = ST_DRV_WAIT_AX_CFG2;
      end

      ST_DRV_WR_AX_CFG3_CMD: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_write;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg3_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG3_ADDR;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG3_CMD;
      end

      ST_DRV_WR_AX_CFG3_ADDR: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_cfg3;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg3_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = (c_tx_ax_cfg3_length - 2);
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG3_DATA;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG3_ADDR;
      end

      ST_DRV_WR_AX_CFG3_DATA: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_len = c_tx_ax_cfg3_length;
         o_tx_data = s_tx_ax_cfg3_aux[((s_byte_index_aux * 8) - 1) -: 8];
         o_tx_enqueue = i_tx_ready;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = (s_byte_index_aux > 1) ? 1'b0 : (i_tx_ready ? 1'b1 : 1'b0);
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = i_tx_ready ? (s_byte_index_aux - 1) : s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            if (s_byte_index_aux > 1)
               s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG3_DATA;
            else
               s_acl2_drv_nx_state = ST_DRV_WAIT_AX_CFG3;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG3_DATA;
      end

      ST_DRV_WAIT_AX_CFG3: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_cfg3_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG4_CMD;
         else s_acl2_drv_nx_state = ST_DRV_WAIT_AX_CFG3;
      end

      ST_DRV_WR_AX_CFG4_CMD: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_write;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg4_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG4_ADDR;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG4_CMD;
      end

      ST_DRV_WR_AX_CFG4_ADDR: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_cfg4;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg4_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = (c_tx_ax_cfg4_length - 2);
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG4_DATA;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG4_ADDR;
      end

      ST_DRV_WR_AX_CFG4_DATA: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = s_tx_ax_cfg4_aux[((s_byte_index_aux * 8) - 1) -: 8];
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg4_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = (s_byte_index_aux > 1) ? 1'b0 : (i_tx_ready ? 1'b1 : 1'b0);
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = i_tx_ready ? (s_byte_index_aux - 1) : s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            if (s_byte_index_aux > 1)
               s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG4_DATA;
            else
               s_acl2_drv_nx_state = ST_DRV_WAIT_AX_CFG4;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG4_DATA;
      end

      ST_DRV_WAIT_AX_CFG4: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_cfg4_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG5_CMD;
         else s_acl2_drv_nx_state = ST_DRV_WAIT_AX_CFG4;
      end

      ST_DRV_WR_AX_CFG5_CMD: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_write;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg5_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG5_ADDR;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG5_CMD;
      end

      ST_DRV_WR_AX_CFG5_ADDR: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_cfg5;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_cfg5_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = (c_tx_ax_cfg5_length - 2);
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG5_DATA;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG5_ADDR;
      end

      ST_DRV_WR_AX_CFG5_DATA: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_len = c_tx_ax_cfg5_length;
         o_tx_data = s_tx_ax_cfg5_aux[((s_byte_index_aux * 8) - 1) -: 8];
         o_tx_enqueue = i_tx_ready;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = (s_byte_index_aux > 1) ? 1'b0 : (i_tx_ready ? 1'b1 : 1'b0);
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = i_tx_ready ? (s_byte_index_aux - 1) : s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            if (s_byte_index_aux > 1)
               s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG5_DATA;
            else
               s_acl2_drv_nx_state = ST_DRV_WAIT_AX_CFG5;
         else
            s_acl2_drv_nx_state = ST_DRV_WR_AX_CFG5_DATA;
      end

      ST_DRV_WAIT_AX_CFG5: begin
         // Refer to the comments in the Configuration 0 sequence.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_cfg5_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_IDLE1;
         else s_acl2_drv_nx_state = ST_DRV_WAIT_AX_CFG5;
      end

      ST_DRV_WAIT_DR_INT1: begin
         // If the SOFT RESET command is held, then transition to SOFT RESET operation.
         // If the Interrupt 1 is indicated (Data Ready status bit), then transition
         // to reading the full measurement of X, Y, Z, Temp.
         // Otherwise, wait for one of these two to occur.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_cmd_soft_reset_acl2) s_acl2_drv_nx_state = ST_DRV_SOFTRESET_CMD;
         else if (ei_int1) s_acl2_drv_nx_state = ST_DRV_READ_MEASU_CMD;
         else s_acl2_drv_nx_state = ST_DRV_WAIT_DR_INT1;
      end

      ST_DRV_READ_MEASU_CMD: begin
         // Load first byte, command READ, to TX FIFO.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_read;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_readmm_length;
         o_rx_len = c_rx_ax_readmm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b1;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_READ_MEASU_ADDR;
         else
            s_acl2_drv_nx_state = ST_DRV_READ_MEASU_CMD;
      end

      ST_DRV_READ_MEASU_ADDR: begin
         // Load second byte, starting address for Measurements 8-byte sequence, to TX FIFO.
         // Then trigger the SPI bus operation.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_8reg;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_readmm_length;
         o_rx_len = c_rx_ax_readmm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = i_tx_ready;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b1;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = c_rx_ax_readmm_length;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_READ_MEASU_DATA;
         else
            s_acl2_drv_nx_state = ST_DRV_READ_MEASU_ADDR;
      end

      ST_DRV_READ_MEASU_DATA: begin
         // Receive the eight bytes of measurment data from the SPI bus operation,
         // and output the bytes one-at-a-time in a streaming pattern.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_readmm_length;
         o_rx_len = c_rx_ax_readmm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = i_rx_avail;
         o_go_stand = 1'b0;
         o_rd_data_stream = i_rx_data;
         o_rd_data_byte_valid = i_rx_valid;
         o_rd_data_group_valid = 1'b1;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = i_rx_valid ? (s_byte_index_aux - 1) : s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if ((i_rx_valid == 1'b1) && (s_byte_index_aux <= 1))
            s_acl2_drv_nx_state = ST_DRV_READ_WAIT0;
         else
            s_acl2_drv_nx_state = ST_DRV_READ_MEASU_DATA;
      end

      ST_DRV_READ_WAIT0: begin
         // End the data stream GROUP signal, and wait for the SPI operation
         // to return to IDLE.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_readmm_length;
         o_rx_len = c_rx_ax_readmm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b1;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_CLEAR_MEASU_CMD;
         else s_acl2_drv_nx_state = ST_DRV_READ_WAIT0;
      end

      ST_DRV_CLEAR_MEASU_CMD: begin
         // Start a clearing of the status register currently indicating
         // DATA READY bit.
         // Load the READ command first.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_read;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_clearmm_length;
         o_rx_len = c_rx_ax_clearmm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_CLEAR_MEASU_ADDR;
         else
            s_acl2_drv_nx_state = ST_DRV_CLEAR_MEASU_CMD;
      end

      ST_DRV_CLEAR_MEASU_ADDR: begin
         // Next, load the STATUS REGISTER address and start the SPI
         // bus operation.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_stat;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_clearmm_length;
         o_rx_len = c_rx_ax_clearmm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = i_tx_ready;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = c_rx_ax_clearmm_length;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_CLEAR_MEASU_DATA;
         else
            s_acl2_drv_nx_state = ST_DRV_CLEAR_MEASU_ADDR;
      end

      ST_DRV_CLEAR_MEASU_DATA: begin
         // Receive a new value for the STATUS REGISTER byte.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_clearmm_length;
         o_rx_len = c_rx_ax_clearmm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = i_rx_avail;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'b00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = i_rx_valid ? (s_byte_index_aux - 1) : s_byte_index_aux;
         s_reg_status_val = i_rx_valid ? i_rx_data : s_reg_status_aux;

         if (i_rx_valid)
            s_acl2_drv_nx_state = ST_DRV_READ_WAIT1;
         else
            s_acl2_drv_nx_state = ST_DRV_CLEAR_MEASU_DATA;
      end

      ST_DRV_READ_WAIT1: begin
         // After reading the STATUS REGISTER, which clears the interrupts,
         // wait for the SPI operation to return to IDLE.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_READ_WAIT2;
         else s_acl2_drv_nx_state = ST_DRV_READ_WAIT1;
      end

      ST_DRV_READ_WAIT2: begin
         // Reading the STATUS REGISTER should have cleared INT1 interrupt
         // pin. If it did, transition to state to wait on interrupt.
         // If it did not, try reading the STATUS REGISTER again.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (! ei_int1) s_acl2_drv_nx_state = ST_DRV_WAIT_DR_INT1;
         else s_acl2_drv_nx_state = ST_DRV_CLEAR_MEASU_CMD;
      end

      ST_DRV_WAIT_AT_INT1: begin
         // If the SOFT RESET command is held, then transition to SOFT RESET operation.
         // If the Interrupt 1 is indicated (Inactivity status bit), then transition
         // to reading the full measurement of X, Y, Z, Temp.
         // If the Interrupt 2 is indicated (Activity status bit), then transition
         // to reading the full measurement of X, Y, Z, Temp.
         // Otherwise, wait for one of these three to occur.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_cmd_soft_reset_acl2) s_acl2_drv_nx_state = ST_DRV_SOFTRESET_CMD;
         else if (ei_int1) s_acl2_drv_nx_state = ST_DRV_READ_INACT0_CMD;
         else if (ei_int2) s_acl2_drv_nx_state = ST_DRV_READ_ACT0_CMD;
         else s_acl2_drv_nx_state = ST_DRV_WAIT_AT_INT1;
      end

      ST_DRV_READ_INACT0_CMD: begin
         // Load first byte, command READ, to TX FIFO.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_read;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_readlm_length;
         o_rx_len = c_rx_ax_readlm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b1;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_READ_INACT0_ADDR;
         else
            s_acl2_drv_nx_state = ST_DRV_READ_INACT0_CMD;
      end

      ST_DRV_READ_INACT0_ADDR: begin
         // Load second byte, starting address for Measurements 8-byte sequence, to TX FIFO.
         // Then trigger the SPI bus operation.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_8reg;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_readlm_length;
         o_rx_len = c_rx_ax_readlm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = i_tx_ready;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b1;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = c_rx_ax_readlm_length;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_READ_INACT0_DATA;
         else
            s_acl2_drv_nx_state = ST_DRV_READ_INACT0_ADDR;
      end

      ST_DRV_READ_INACT0_DATA: begin
         // Load second byte, starting address for Measurements 8-byte sequence, to TX FIFO.
         // Then trigger the SPI bus operation.
         o_command_ready = 1'b0;
         o_tx_len = c_tx_ax_readlm_length;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_rx_len = c_rx_ax_readlm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = i_rx_avail;
         o_go_stand = 1'b0;
         o_rd_data_stream = i_rx_data;
         o_rd_data_byte_valid = i_rx_valid;
         o_rd_data_group_valid = 1'b1;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = i_rx_valid ? (s_byte_index_aux - 1) : s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if ((i_rx_valid == 1'b1) && (s_byte_index_aux <= 1))
            s_acl2_drv_nx_state = ST_DRV_READ_WAIT3;
         else
            s_acl2_drv_nx_state = ST_DRV_READ_INACT0_DATA;
      end

      ST_DRV_READ_WAIT3: begin
         // End the data stream GROUP signal, and wait for the SPI operation
         // to return to IDLE.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_readlm_length;
         o_rx_len = c_rx_ax_readlm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b1;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE0_CMD;
         else s_acl2_drv_nx_state = ST_DRV_READ_WAIT3;
      end

      ST_DRV_CLEAR_AWAKE0_CMD: begin
         // Start a clearing of the status register currently indicating
         // INACTIVITY bit.
         // Load the READ command first.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_read;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_clearlm_length;
         o_rx_len = c_rx_ax_clearlm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE0_ADDR;
         else
            s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE0_CMD;
      end

      ST_DRV_CLEAR_AWAKE0_ADDR: begin
         // Next, load the STATUS REGISTER address and start the SPI
         // bus operation.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_stat;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_clearlm_length;
         o_rx_len = c_rx_ax_clearlm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = i_tx_ready;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = c_rx_ax_clearlm_length;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE0_DATA;
         else
            s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE0_ADDR;
      end

      ST_DRV_CLEAR_AWAKE0_DATA: begin
         // Receive a new value for the STATUS REGISTER byte.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_clearmm_length;
         o_rx_len = c_rx_ax_clearmm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = i_rx_avail;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'b00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = i_rx_valid ? (s_byte_index_aux - 1) : s_byte_index_aux;
         s_reg_status_val = i_rx_valid ? i_rx_data : s_reg_status_aux;

         if (i_rx_valid)
            s_acl2_drv_nx_state = ST_DRV_READ_WAIT4;
         else
            s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE0_DATA;
      end

      ST_DRV_READ_WAIT4: begin
         // After reading the STATUS REGISTER, which clears the interrupts,
         // wait for the SPI operation to return to IDLE.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_READ_WAIT5;
         else s_acl2_drv_nx_state = ST_DRV_READ_WAIT4;
      end

      ST_DRV_READ_WAIT5: begin
         // Reading the STATUS REGISTER should have cleared INT1 interrupt
         // pin. If it did, transition to state to wait on interrupt.
         // If it did not, try reading the STATUS REGISTER again.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (! ei_int1) s_acl2_drv_nx_state = ST_DRV_WAIT_AT_INT2;
         else s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE0_CMD;
      end

      ST_DRV_WAIT_AT_INT2: begin
         // If the SOFT RESET command is held, then transition to SOFT RESET operation.
         // If the Interrupt 2 is indicated (Activity status bit), then transition
         // to reading the full measurement of X, Y, Z, Temp.
         // If the Interrupt 1 is indicated (Inactivity status bit), then transition
         // to reading the full measurement of X, Y, Z, Temp.
         // Otherwise, wait for one of these three to occur.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_cmd_soft_reset_acl2) s_acl2_drv_nx_state = ST_DRV_SOFTRESET_CMD;
         else if (ei_int2) s_acl2_drv_nx_state = ST_DRV_READ_ACT0_CMD;
         else if (ei_int1) s_acl2_drv_nx_state = ST_DRV_READ_INACT0_CMD;
         else s_acl2_drv_nx_state = ST_DRV_WAIT_AT_INT2;
      end

      ST_DRV_READ_ACT0_CMD: begin
         // Load first byte, command READ, to TX FIFO.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_read;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_readlm_length;
         o_rx_len = c_rx_ax_readlm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b1;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_READ_ACT0_ADDR;
         else
            s_acl2_drv_nx_state = ST_DRV_READ_ACT0_CMD;
      end

      ST_DRV_READ_ACT0_ADDR: begin
         // Load second byte, starting address for Measurements 8-byte sequence, to TX FIFO.
         // At the same time, trigger the SPI bus operation.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_8reg;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_readlm_length;
         o_rx_len = c_rx_ax_readlm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = i_tx_ready;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b1;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = c_rx_ax_readlm_length;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_READ_ACT0_DATA;
         else
            s_acl2_drv_nx_state = ST_DRV_READ_ACT0_ADDR;
      end

      ST_DRV_READ_ACT0_DATA: begin
         // Receive the eight bytes of measurment data from the SPI bus operation,
         // and output the bytes one-at-a-time in a streaming pattern.
         o_command_ready = 1'b0;
         o_tx_len = c_tx_ax_readlm_length;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_rx_len = c_rx_ax_readlm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = i_rx_avail;
         o_go_stand = 1'b0;
         o_rd_data_stream = i_rx_data;
         o_rd_data_byte_valid = i_rx_valid;
         o_rd_data_group_valid = 1'b1;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = i_rx_valid ? (s_byte_index_aux - 1) : s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if ((i_rx_valid == 1'b1) && (s_byte_index_aux <= 1))
            s_acl2_drv_nx_state = ST_DRV_READ_WAIT6;
         else
            s_acl2_drv_nx_state = ST_DRV_READ_ACT0_DATA;
      end

      ST_DRV_READ_WAIT6: begin
         // End the data stream GROUP signal, and wait for the SPI operation
         // to return to IDLE.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_readlm_length;
         o_rx_len = c_rx_ax_readlm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b1;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE1_CMD;
         else s_acl2_drv_nx_state = ST_DRV_READ_WAIT6;
      end

      ST_DRV_CLEAR_AWAKE1_CMD: begin
         // Start a clearing of the status register currently indicating
         // ACTIVITY bit.
         // Load the READ command first.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_read;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_clearlm_length;
         o_rx_len = c_rx_ax_clearlm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE1_ADDR;
         else
            s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE1_CMD;
      end

      ST_DRV_CLEAR_AWAKE1_ADDR: begin
         // Next, load the STATUS REGISTER address and start the SPI
         // bus operation.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_stat;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_clearlm_length;
         o_rx_len = c_rx_ax_clearlm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = i_tx_ready;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = c_rx_ax_clearlm_length;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE1_DATA;
         else
            s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE1_ADDR;
      end

      ST_DRV_CLEAR_AWAKE1_DATA: begin
         // Receive a new value for the STATUS REGISTER byte.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_clearmm_length;
         o_rx_len = c_rx_ax_clearmm_length;
         o_wait_cyc = 0;
         o_rx_dequeue = i_rx_avail;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'b00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = i_rx_valid ? (s_byte_index_aux - 1) : s_byte_index_aux;
         s_reg_status_val = i_rx_valid ? i_rx_data : s_reg_status_aux;

         if (i_rx_valid)
            s_acl2_drv_nx_state = ST_DRV_READ_WAIT7;
         else
            s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE1_DATA;
      end

      ST_DRV_READ_WAIT7: begin
         // After reading the STATUS REGISTER, which clears the interrupts,
         // wait for the SPI operation to return to IDLE.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_READ_WAIT8;
         else s_acl2_drv_nx_state = ST_DRV_READ_WAIT7;
      end

      ST_DRV_READ_WAIT8: begin
         // Reading the STATUS REGISTER should have cleared INT2 interrupt
         // pin. If it did, transition to state to wait on interrupt.
         // If it did not, try reading the STATUS REGISTER again.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (! ei_int2) s_acl2_drv_nx_state = ST_DRV_WAIT_AT_INT1;
         else s_acl2_drv_nx_state = ST_DRV_CLEAR_AWAKE1_CMD;
      end

      ST_DRV_SOFTRESET_CMD: begin
         // Start the writing of the SOFT RESET byte to the SOFT RESET REGISTER.
         // First, load the WRITE command.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_cmd_write;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_sr_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_SOFTRESET_ADDR;
         else
            s_acl2_drv_nx_state = ST_DRV_SOFTRESET_CMD;
      end

      ST_DRV_SOFTRESET_ADDR: begin
         // Next, load the address of the SOFT RESET REGISTER.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_addr_sr;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_sr_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = c_tx_ax_sr_length - 2;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_SOFTRESET_DATA;
         else
            s_acl2_drv_nx_state = ST_DRV_SOFTRESET_ADDR;
      end

      ST_DRV_SOFTRESET_DATA: begin
         // Finally, load the data value that is command to SOFT RESET,
         // and at the same time trigger the SPI operation to start.
         o_command_ready = 1'b0;
         o_tx_data = c_adxl362_data_sr;
         o_tx_enqueue = i_tx_ready;
         o_tx_len = c_tx_ax_sr_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = i_tx_ready;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = i_tx_ready ? (s_byte_index_aux - 1) : s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_tx_ready)
            s_acl2_drv_nx_state = ST_DRV_SOFTRESET_WAIT9;
         else
            s_acl2_drv_nx_state = ST_DRV_SOFTRESET_DATA;
      end

      ST_DRV_SOFTRESET_WAIT9: begin
         // Wait for the SPI operation to return to IDLE. Then
         // transition to the BOOT state to reboot the ADXL362.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = c_tx_ax_sr_length;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_spi_idle) s_acl2_drv_nx_state = ST_DRV_BOOT0;
         else s_acl2_drv_nx_state = ST_DRV_SOFTRESET_WAIT9;
      end

      ST_DRV_IDLE1: begin
         // IDLE the state machine and wait for either a START LINKED MODE
         // or START MESASUREMENT MODE command to transition. If transitioning
         // to LINKED MODE, then wait on Inactivity and then Activity, back
         // and forth. If transitioning to MEASUREMENT MODE, then wait for
         // 100 Hz DATA READY interrupt.
         o_command_ready = i_spi_idle;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_cmd_start_linked_mode) s_acl2_drv_nx_state = ST_DRV_WAIT_AT_INT1;
         else if (i_cmd_start_measur_mode) s_acl2_drv_nx_state =
            ST_DRV_WAIT_DR_INT1;
         else s_acl2_drv_nx_state = ST_DRV_IDLE1;
      end

      ST_DRV_IDLE0: begin
         // IDLE the state machine and wait for either a INIT LINKED MODE
         // or INIT MESASUREMENT MODE command to transition. If transitioning
         // to LINKED MODE, then run the configuration sequence with respective
         // configuration settings. If transitioning to MEASUREMENT MODE, then
         // run the configuration sequence with respective configuration
         // settings.
         o_command_ready = i_spi_idle;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (i_cmd_init_linked_mode) s_acl2_drv_nx_state = ST_DRV_INIT_LM;
         else if (i_cmd_init_measur_mode) s_acl2_drv_nx_state = ST_DRV_INIT_MM;
         else s_acl2_drv_nx_state = ST_DRV_IDLE0;
      end

      default: begin // ST_DRV_BOOT0
         // Wait \ref c_t_adx1362_boot time before talking with the ADXL362.
         o_command_ready = 1'b0;
         o_tx_data = 8'h00;
         o_tx_enqueue = 1'b0;
         o_tx_len = 0;
         o_rx_len = 0;
         o_wait_cyc = 0;
         o_rx_dequeue = 1'b0;
         o_go_stand = 1'b0;
         o_rd_data_stream = 8'h00;
         o_rd_data_byte_valid = 1'b0;
         o_rd_data_group_valid = 1'b0;
         s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
         s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
         s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
         s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
         s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
         s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
         s_byte_index_val = s_byte_index_aux;
         s_reg_status_val = s_reg_status_aux;

         if (s_t == c_t_adxl362_boot - 1) s_acl2_drv_nx_state = ST_DRV_IDLE0;
         else s_acl2_drv_nx_state = ST_DRV_BOOT0;
      end
   endcase
end

endmodule
//------------------------------------------------------------------------------
