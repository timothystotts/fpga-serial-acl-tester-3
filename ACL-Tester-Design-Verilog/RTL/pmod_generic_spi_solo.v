/*------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020 Timothy Stotts
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
-- \file pmod_generic_spi_solo.v
--
-- \brief A custom SPI driver for generic usage, implementing only Standard
-- SPI operating in Mode 0, without Extended data transfer of more than the
-- standard COPI and CIPO data signals.
------------------------------------------------------------------------------*/
//------------------------------------------------------------------------------
//Multiple Recursive Moore Machines
//Part 1: Module header:--------------------------------------------------------
module pmod_generic_spi_solo (
	/* SPI bus outputs and input to top-level */
	eo_sck_o, eo_sck_t, eo_csn_o, eo_csn_t, eo_copi_o, eo_copi_t, ei_cipo_i,
	/* SPI state machine clock at 4x the SPI bus clock speed, with
	   synchronous reset */
	i_ext_spi_clk_x, i_srst, i_spi_ce_4x,
	/* inputs and output for triggering a new SPI bus cycle */
	i_go_stand, o_spi_idle, i_tx_len, i_wait_cyc, i_rx_len,
	/* system interface to TX FIFO */
	i_tx_data, i_tx_enqueue, o_tx_ready,
	/* system interface to RX FIFO */
	o_rx_data, i_rx_dequeue, o_rx_valid, o_rx_avail);

/* Ratio of i_ext_spi_clk_x to SPI sck bus output. */
parameter parm_ext_spi_clk_ratio = 32;
/* LOG2 of the TX FIFO max count */
parameter parm_tx_len_bits = 11;
/* LOG2 of max Wait Cycles count between end of TX and start of RX */
parameter parm_wait_cyc_bits = 2;
/* LOG2 of the RX FIFO max count */
parameter parm_rx_len_bits = 11; /* now ignored due to usage of MACRO */

output reg eo_sck_o;
output reg eo_sck_t;
output reg eo_csn_o;
output reg eo_csn_t;
output reg eo_copi_o;
output reg eo_copi_t;
input wire ei_cipo_i;

input wire i_ext_spi_clk_x;
input wire i_srst;
input wire i_spi_ce_4x;

input wire i_go_stand;
output wire o_spi_idle;
input wire [(parm_tx_len_bits - 1):0] i_tx_len;
input wire [(parm_wait_cyc_bits - 1):0] i_wait_cyc;
input wire [(parm_rx_len_bits - 1):0] i_rx_len;

input wire [7:0] i_tx_data;
input wire i_tx_enqueue;
output wire o_tx_ready;

output wire [7:0] o_rx_data;
input wire i_rx_dequeue;
output wire o_rx_valid;
output wire o_rx_avail;

// Part 2: Declarations---------------------------------------------------------
/* SPI FSM state declarations */
`define c_spi_state_bits 3
localparam [(`c_spi_state_bits - 1):0] ST_STAND_IDLE = 3'd0;
localparam [(`c_spi_state_bits - 1):0] ST_STAND_START_D = 3'd1;
localparam [(`c_spi_state_bits - 1):0] ST_STAND_START_S = 3'd2;
localparam [(`c_spi_state_bits - 1):0] ST_STAND_TX = 3'd3;
localparam [(`c_spi_state_bits - 1):0] ST_STAND_WAIT = 3'd4;
localparam [(`c_spi_state_bits - 1):0] ST_STAND_RX = 3'd5;
localparam [(`c_spi_state_bits - 1):0] ST_STAND_STOP_S = 3'd6;
localparam [(`c_spi_state_bits - 1):0] ST_STAND_STOP_D = 3'd7;

/* Xilinx attributes for gray encoding of the FSM and safe state is
   Default State. */
(* fsm_encoding = "gray" *)
(* fsm_safe_state = "default_state" *)
reg [(`c_spi_state_bits - 1):0] s_spi_pr_state = ST_STAND_IDLE;
reg [(`c_spi_state_bits - 1):0] s_spi_nx_state = ST_STAND_IDLE;
reg [(`c_spi_state_bits - 1):0] s_spi_pr_state_delayed1 = ST_STAND_IDLE;
reg [(`c_spi_state_bits - 1):0] s_spi_pr_state_delayed2 = ST_STAND_IDLE;
reg [(`c_spi_state_bits - 1):0] s_spi_pr_state_delayed3 = ST_STAND_IDLE;

/* Data start FSM state declarations */
`define c_dat_state_bits 3
localparam [(`c_dat_state_bits - 1):0] ST_PULSE_WAIT = 3'd0;
localparam [(`c_dat_state_bits - 1):0] ST_PULSE_HOLD_0 = 3'd1;
localparam [(`c_dat_state_bits - 1):0] ST_PULSE_HOLD_1 = 3'd2;
localparam [(`c_dat_state_bits - 1):0] ST_PULSE_HOLD_2 = 3'd3;
localparam [(`c_dat_state_bits - 1):0] ST_PULSE_HOLD_3 = 3'd4;

/* Xilinx attributes for Gray encoding of the FSM and safe state is
   Default State. */
(* fsm_encoding = "gray" *)
(* fsm_safe_state = "default_state" *)
reg [(`c_dat_state_bits - 1):0] s_dat_pr_state = ST_PULSE_WAIT;
reg [(`c_dat_state_bits - 1):0] s_dat_nx_state = ST_PULSE_WAIT;

/* Timer signals and constants */
`define c_tim_value_bits 13
localparam [(`c_tim_value_bits - 1):0] c_t_stand_wait_ss = 4;
localparam [(`c_tim_value_bits - 1):0] c_t_stand_max_tx = 4144;
localparam [(`c_tim_value_bits - 1):0] c_t_stand_max_wait = 31;
localparam [(`c_tim_value_bits - 1):0] c_t_stand_max_rx = 4136;
localparam [(`c_tim_value_bits - 1):0] c_tmax = c_t_stand_max_tx;
localparam [(`c_tim_value_bits - 1):0] c_t_inc = 1;

reg [(`c_tim_value_bits - 1):0] s_t;
reg [(`c_tim_value_bits - 1):0] s_t_delayed1;
reg [(`c_tim_value_bits - 1):0] s_t_delayed2;
reg [(`c_tim_value_bits - 1):0] s_t_delayed3;

/* SPI 4x and 1x clocking signals and enables */
wire s_spi_ce_4x;
wire s_spi_clk_1x;

wire s_spi_clk_ce0;
wire s_spi_clk_ce1;
wire s_spi_clk_ce2;
wire s_spi_clk_ce3;

/* FSM pulse stretched */
wire s_go_stand;

/* FSM auxiliary registers */
reg [(parm_tx_len_bits - 1):0] s_tx_len_val;
reg [(parm_tx_len_bits - 1):0] s_tx_len_aux;
reg [(parm_rx_len_bits - 1):0] s_rx_len_val;
reg [(parm_rx_len_bits - 1):0] s_rx_len_aux;
reg [(parm_wait_cyc_bits - 1):0] s_wait_cyc_val;
reg [(parm_wait_cyc_bits - 1):0] s_wait_cyc_aux;
reg s_go_stand_val;
reg s_go_stand_aux;

/* FSM output status */
reg s_spi_idle;

/* Mapping for FIFO RX */
reg [7:0] s_data_fifo_rx_in;
wire [7:0] s_data_fifo_rx_out;
wire s_data_fifo_rx_re;
reg s_data_fifo_rx_we;
wire s_data_fifo_rx_full;
wire s_data_fifo_rx_empty;
reg s_data_fifo_rx_valid;
wire [10:0] s_data_fifo_rx_rdcount;
wire [10:0] s_data_fifo_rx_wrcount;
wire s_data_fifo_rx_almostfull;
wire s_data_fifo_rx_almostempty;
wire s_data_fifo_rx_wrerr;
wire s_data_fifo_rx_rderr;

/* Mapping for FIFO TX */
wire [7:0] s_data_fifo_tx_in;
wire [7:0] s_data_fifo_tx_out;
reg s_data_fifo_tx_re;
wire s_data_fifo_tx_we;
wire s_data_fifo_tx_full;
wire s_data_fifo_tx_empty;
reg s_data_fifo_tx_valid;
wire [10:0] s_data_fifo_tx_rdcount;
wire [10:0] s_data_fifo_tx_wrcount;
wire s_data_fifo_tx_almostfull;
wire s_data_fifo_tx_almostempty;
wire s_data_fifo_tx_wrerr;
wire s_data_fifo_tx_rderr;

//Part 3: Statements------------------------------------------------------------
/* The SPI driver is IDLE only if the state signals as IDLE and more than four
   clock cycles have elapsed since a system clock pulse on input
   \ref i_go_stand.
   */
assign o_spi_idle = ((s_spi_idle == 1'b1) &&
					 (s_dat_pr_state == ST_PULSE_WAIT)) ? 1'b1 : 1'b0;

/* In this implementation, the 4x SPI clock is operated by a clock enable against
   the system clock \ref i_ext_spi_clk_x . */
assign s_spi_ce_4x = i_spi_ce_4x;

/* Mapping of the RX FIFO to external control and reception of data for
   reading operations */
assign o_rx_avail = (~ s_data_fifo_rx_empty) & s_spi_ce_4x;
assign o_rx_valid = s_data_fifo_rx_valid & s_spi_ce_4x;
assign s_data_fifo_rx_re = i_rx_dequeue & s_spi_ce_4x;
assign o_rx_data = s_data_fifo_rx_out;

always @(posedge i_ext_spi_clk_x)
begin: p_gen_fifo_rx_valid
	s_data_fifo_rx_valid <= s_data_fifo_rx_re;
end

// FIFO_SYNC_MACRO: Synchronous First-In, First-Out (FIFO) RAM Buffer
//                  Artix-7
// Xilinx HDL Language Template, version 2019.1

/////////////////////////////////////////////////////////////////
// DATA_WIDTH | FIFO_SIZE | FIFO Depth | RDCOUNT/WRCOUNT Width //
// ===========|===========|============|=======================//
//   37-72    |  "36Kb"   |     512    |         9-bit         //
//   19-36    |  "36Kb"   |    1024    |        10-bit         //
//   19-36    |  "18Kb"   |     512    |         9-bit         //
//   10-18    |  "36Kb"   |    2048    |        11-bit         //
//   10-18    |  "18Kb"   |    1024    |        10-bit         //
//    5-9     |  "36Kb"   |    4096    |        12-bit         //
//    5-9     |  "18Kb"   |    2048    |        11-bit         //
//    1-4     |  "36Kb"   |    8192    |        13-bit         //
//    1-4     |  "18Kb"   |    4096    |        12-bit         //
/////////////////////////////////////////////////////////////////

FIFO_SYNC_MACRO  #(
  .DEVICE("7SERIES"), // Target Device: "7SERIES" 
  .ALMOST_EMPTY_OFFSET(11'h080), // Sets the almost empty threshold
  .ALMOST_FULL_OFFSET(11'h080),  // Sets almost full threshold
  .DATA_WIDTH(8), // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
  .DO_REG(0),     // Optional output register (0 or 1)
  .FIFO_SIZE ("18Kb")  // Target BRAM: "18Kb" or "36Kb" 
) u_fifo_rx_0 (
  .ALMOSTEMPTY(s_data_fifo_rx_almostempty), // 1-bit output almost empty
  .ALMOSTFULL(s_data_fifo_rx_almostfull),   // 1-bit output almost full
  .DO(s_data_fifo_rx_out),                  // Output data, width defined by DATA_WIDTH parameter
  .EMPTY(s_data_fifo_rx_empty),             // 1-bit output empty
  .FULL(s_data_fifo_rx_full),               // 1-bit output full
  .RDCOUNT(s_data_fifo_rx_rdcount),         // Output read count, width determined by FIFO depth
  .RDERR(s_data_fifo_rx_rderr),             // 1-bit output read error
  .WRCOUNT(s_data_fifo_rx_wrcount),         // Output write count, width determined by FIFO depth
  .WRERR(s_data_fifo_rx_wrerr),             // 1-bit output write error
  .CLK(i_ext_spi_clk_x),                    // 1-bit input clock
  .DI(s_data_fifo_rx_in),                   // Input data, width defined by DATA_WIDTH parameter
  .RDEN(s_data_fifo_rx_re),                 // 1-bit input read enable
  .RST(i_srst),                             // 1-bit input reset
  .WREN(s_data_fifo_rx_we)                  // 1-bit input write enable
);
// End of FIFO_SYNC_MACRO_inst instantiation
				
/* Mapping of the TX FIFO to external control and transmission of data for
   writing operations */
assign s_data_fifo_tx_in = i_tx_data;
assign s_data_fifo_tx_we = i_tx_enqueue & s_spi_ce_4x;
assign o_tx_ready = (~ s_data_fifo_tx_full) & s_spi_ce_4x;

always @(posedge i_ext_spi_clk_x)
begin: p_gen_fifo_tx_valid
	s_data_fifo_tx_valid <= s_data_fifo_tx_re;
end

// FIFO_SYNC_MACRO: Synchronous First-In, First-Out (FIFO) RAM Buffer
//                  Artix-7
// Xilinx HDL Language Template, version 2019.1

/////////////////////////////////////////////////////////////////
// DATA_WIDTH | FIFO_SIZE | FIFO Depth | RDCOUNT/WRCOUNT Width //
// ===========|===========|============|=======================//
//   37-72    |  "36Kb"   |     512    |         9-bit         //
//   19-36    |  "36Kb"   |    1024    |        10-bit         //
//   19-36    |  "18Kb"   |     512    |         9-bit         //
//   10-18    |  "36Kb"   |    2048    |        11-bit         //
//   10-18    |  "18Kb"   |    1024    |        10-bit         //
//    5-9     |  "36Kb"   |    4096    |        12-bit         //
//    5-9     |  "18Kb"   |    2048    |        11-bit         //
//    1-4     |  "36Kb"   |    8192    |        13-bit         //
//    1-4     |  "18Kb"   |    4096    |        12-bit         //
/////////////////////////////////////////////////////////////////

FIFO_SYNC_MACRO  #(
  .DEVICE("7SERIES"), // Target Device: "7SERIES" 
  .ALMOST_EMPTY_OFFSET(11'h080), // Sets the almost empty threshold
  .ALMOST_FULL_OFFSET(11'h080),  // Sets almost full threshold
  .DATA_WIDTH(8), // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
  .DO_REG(0),     // Optional output register (0 or 1)
  .FIFO_SIZE ("18Kb")  // Target BRAM: "18Kb" or "36Kb" 
) u_fifo_tx_0 (
  .ALMOSTEMPTY(s_data_fifo_tx_almostempty), // 1-bit output almost empty
  .ALMOSTFULL(s_data_fifo_tx_almostfull),   // 1-bit output almost full
  .DO(s_data_fifo_tx_out),                  // Output data, width defined by DATA_WIDTH parameter
  .EMPTY(s_data_fifo_tx_empty),             // 1-bit output empty
  .FULL(s_data_fifo_tx_full),               // 1-bit output full
  .RDCOUNT(s_data_fifo_tx_rdcount),         // Output read count, width determined by FIFO depth
  .RDERR(s_data_fifo_tx_rderr),             // 1-bit output read error
  .WRCOUNT(s_data_fifo_tx_wrcount),         // Output write count, width determined by FIFO depth
  .WRERR(s_data_fifo_tx_wrerr),             // 1-bit output write error
  .CLK(i_ext_spi_clk_x),                    // 1-bit input clock
  .DI(s_data_fifo_tx_in),                   // Input data, width defined by DATA_WIDTH parameter
  .RDEN(s_data_fifo_tx_re),                 // 1-bit input read enable
  .RST(i_srst),                             // 1-bit input reset
  .WREN(s_data_fifo_tx_we)                  // 1-bit input write enable
);
// End of FIFO_SYNC_MACRO_inst instantiation

/* spi clock for SCK output, generated clock
   requires create_generated_clock constraint in XDC */
clock_divider #(.par_clk_divisor(parm_ext_spi_clk_ratio)) u_spi_1x_clock_divider (
	.o_clk_div(s_spi_clk_1x),
	.o_rst_div(),
	.i_clk_mhz(i_ext_spi_clk_x),
	.i_rst_mhz(i_srst));

integer v_phase_counter;

/* 25% point clock enables for period of 4 times SPI CLK output based on s_spi_ce_4x */
always @(posedge i_ext_spi_clk_x)
begin: p_phase_4x_ce
	if (i_srst)
		v_phase_counter <= 0;
	else
		if (v_phase_counter < parm_ext_spi_clk_ratio - 1)
			v_phase_counter <= v_phase_counter + 1;
		else
			v_phase_counter <= 0;
end

assign s_spi_clk_ce0 = (v_phase_counter == parm_ext_spi_clk_ratio / 4 * 0) && s_spi_ce_4x;
assign s_spi_clk_ce1 = (v_phase_counter == parm_ext_spi_clk_ratio / 4 * 1) && s_spi_ce_4x;
assign s_spi_clk_ce2 = (v_phase_counter == parm_ext_spi_clk_ratio / 4 * 2) && s_spi_ce_4x;
assign s_spi_clk_ce3 = (v_phase_counter == parm_ext_spi_clk_ratio / 4 * 3) && s_spi_ce_4x;

/* Timer 1 (Strategy #1) with comstant timer increment */
always @(posedge i_ext_spi_clk_x)
begin: p_timer_1
	if (i_srst) begin
		s_t <= 0;
		s_t_delayed1 <= 0;
		s_t_delayed2 <= 0;
		s_t_delayed3 <= 0;
	end else begin
		if (i_spi_ce_4x) begin
			s_t_delayed3 <= s_t_delayed2;
			s_t_delayed2 <= s_t_delayed1;
			s_t_delayed1 <= s_t;
		end

		if (s_spi_clk_ce2) /* clock enable on falling SPI edge for timer change
			                */
			if (s_spi_pr_state != s_spi_nx_state) s_t <= 0;
			else if (s_t < c_tmax) s_t <= s_t + c_t_inc;
	end
end

/* System Data GO data value holder and i_go_stand pulse stretcher for duration
   of all four clock enables duration of the 4x clock, starting at a clock
   enable position. State assignment and Auxiliary register assignment. */
always @(posedge i_ext_spi_clk_x)
begin: p_dat_fsm_state_aux
	if (i_srst) begin
		s_dat_pr_state <= ST_PULSE_WAIT;

		s_tx_len_aux <= 0;
		s_rx_len_aux <= 0;
		s_wait_cyc_aux <= 0;
		s_go_stand_aux <= 1'b0;
	end else
		if (s_spi_ce_4x) begin
			/* no clock enable as this is a system-side interface */
			s_dat_pr_state <= s_dat_nx_state;

			/* auxiliary assignments */
			s_tx_len_aux <= s_tx_len_val;
			s_rx_len_aux <= s_rx_len_val;
			s_wait_cyc_aux <= s_wait_cyc_val;
			s_go_stand_aux <= s_go_stand_val;
		end
end

/* Pass the auxiliary signal that lasts for a single iteration of all four
   s_spi_clk_4x clock enables on to the \ref p_spi_fsm_comb machine. */
assign s_go_stand = s_go_stand_aux;

/* System Data GO data value holder and i_go_stand pulse stretcher for all
   four clock enables duration of the 4x clock, starting at an clock enable
   position. Combinatorial logic paired with the \ref p_dat_fsm_state
   assignments. */
always @(s_dat_pr_state, i_go_stand,
	i_tx_len, i_rx_len, i_wait_cyc,
	s_tx_len_aux, s_rx_len_aux, s_wait_cyc_aux,
	s_go_stand_aux)
begin: p_dat_fsm_comb
	case (s_dat_pr_state)
		ST_PULSE_HOLD_0: begin
			/* Hold the GO signal and auxiliary for this cycle. */
			s_go_stand_val = s_go_stand_aux;
			s_tx_len_val = s_tx_len_aux;
			s_rx_len_val = s_rx_len_aux;
			s_wait_cyc_val = s_wait_cyc_aux;
			s_dat_nx_state = ST_PULSE_HOLD_1;
		end
		ST_PULSE_HOLD_1: begin
			/* Hold the GO signal and auxiliary for this cycle. */
			s_go_stand_val = s_go_stand_aux;
			s_tx_len_val = s_tx_len_aux;
			s_rx_len_val = s_rx_len_aux;
			s_wait_cyc_val = s_wait_cyc_aux;
			s_dat_nx_state = ST_PULSE_HOLD_2;
		end
		ST_PULSE_HOLD_2: begin
			/* Hold the GO signal and auxiliary for this cycle. */
			s_go_stand_val = s_go_stand_aux;
			s_tx_len_val = s_tx_len_aux;
			s_rx_len_val = s_rx_len_aux;
			s_wait_cyc_val = s_wait_cyc_aux;
			s_dat_nx_state = ST_PULSE_HOLD_3;
		end
		ST_PULSE_HOLD_3: begin
			/* Reset the GO signal and and hold the auxiliary for this cycle. */
			s_go_stand_val = 1'b0;
			s_tx_len_val = s_tx_len_aux;
			s_rx_len_val = s_rx_len_aux;
			s_wait_cyc_val = s_wait_cyc_aux;
			s_dat_nx_state = ST_PULSE_WAIT;
		end

		default: begin /* ST_PULSE_WAIT */
			/* If GO signal is 1, assign it and the auxiliary on the
			   transition to the first HOLD state. Otherwise, hold
			   the values already assigned. */
			if (i_go_stand) begin
				s_go_stand_val = i_go_stand;
				s_tx_len_val = i_tx_len;
				s_rx_len_val = i_rx_len;
				s_wait_cyc_val = i_wait_cyc;
				s_dat_nx_state = ST_PULSE_HOLD_0;
			end else begin
				s_go_stand_val = s_go_stand_aux;
				s_tx_len_val = s_tx_len_aux;
				s_rx_len_val = s_rx_len_aux;
				s_wait_cyc_val = s_wait_cyc_aux;
				s_dat_nx_state = ST_PULSE_WAIT;
			end
		end
	endcase
end

/* SPI bus control state machine assignments for falling edge of 1x clock
   assignment of state value, plus delayed state value for the RX capture
   on the SPI rising edge of 1x clock in a different process. */
always @(posedge i_ext_spi_clk_x)
begin: p_spi_fsm_state
	if (i_srst) begin
		s_spi_pr_state_delayed3 <= ST_STAND_IDLE;
		s_spi_pr_state_delayed2 <= ST_STAND_IDLE;
		s_spi_pr_state_delayed1 <= ST_STAND_IDLE;
		s_spi_pr_state <= ST_STAND_IDLE;
	end else begin
		/* The delayed state value allows for registration of TX clock
		   and double registration of RX value to capture after the
		   registration of outputs and synchronization of inputs. */
		if (s_spi_ce_4x) begin
			s_spi_pr_state_delayed3 <= s_spi_pr_state_delayed2;
			s_spi_pr_state_delayed2 <= s_spi_pr_state_delayed1;
			s_spi_pr_state_delayed1 <= s_spi_pr_state;
		end

		if (s_spi_clk_ce2) /* clock enable on falling SPI edge for state change
			                */
			s_spi_pr_state <= s_spi_nx_state;
	end
end

/* SPI bus control state machine assignments for combinatorial assignment to
   SPI bus outputs, timing of chip select, transmission of TX data,
   holding for wait cycles, and timing for RX data where RX data is captured
   in a different synchronous state machine delayed from the state of this
   machine. */
always @(s_spi_pr_state, s_spi_clk_1x, s_go_stand,
		 s_tx_len_aux, s_rx_len_aux, s_wait_cyc_aux,
	     s_t,
		 s_data_fifo_tx_empty, s_data_fifo_tx_out,
		 s_spi_clk_ce2, s_spi_clk_ce3)
begin: p_spi_fsm_comb
	case (s_spi_pr_state)
		ST_STAND_START_D: begin
			/* halt clock at Mode 0 */
			eo_sck_o = 1'b0;
			eo_sck_t = 1'b0;
			/* no chip select */
			eo_csn_o = 1'b1;
			eo_csn_t = 1'b0;
			/* zero value for COPI */
			eo_copi_o = 1'b0;
			eo_copi_t = 1'b0;
			/* hold not reading the TX FIFO */
			s_data_fifo_tx_re = 1'b0;
			/* machine is not idle */
			s_spi_idle = 1'b0;

			/* time the chip not selected start time */
			if (s_t == c_t_stand_wait_ss - c_t_inc)
				s_spi_nx_state = ST_STAND_START_S;
			else s_spi_nx_state = ST_STAND_START_D;
		end

		ST_STAND_START_S: begin
			/* halt clock at Mode 0 */
			eo_sck_o = 1'b0;
			eo_sck_t = 1'b0;
			/* assert chip select */
			eo_csn_o = 1'b0;
			eo_csn_t = 1'b0;
			/* zero value for COPI */
			eo_copi_o = 1'b0;
			eo_copi_t = 1'b0;
			/* hold not reading the TX FIFO */
			s_data_fifo_tx_re = 1'b0;
			/* machine is not idle */
			s_spi_idle = 1'b0;

			s_data_fifo_tx_re = ((s_t == c_t_stand_wait_ss - c_t_inc) &&
				(s_data_fifo_tx_empty == 1'b0)) ? s_spi_clk_ce3 : 1'b0;

			/* time the chip selected start time */
			if (s_t == c_t_stand_wait_ss - c_t_inc)
				s_spi_nx_state = ST_STAND_TX;
			else s_spi_nx_state = ST_STAND_START_S;
		end

		ST_STAND_TX: begin
			/* run clock at Mode 0 */
			eo_sck_o = s_spi_clk_1x;
			eo_sck_t = 1'b0;
			/* assert chip select */
			eo_csn_o = 1'b0;
			eo_csn_t = 1'b0;
			/* data value for COPI */
			eo_copi_o = (s_t < 8 * s_tx_len_aux) ? s_data_fifo_tx_out[7 - (s_t % 8)] : 1'b0;
			eo_copi_t = 1'b0;

			/* machine is not idle */
			s_spi_idle = 1'b0;

			/* read byte by byte from the TX FIFO */
			/* only if on last bit, dequeue another byte */
			s_data_fifo_tx_re = ((s_t != (8 * s_tx_len_aux) - c_t_inc) && (s_t % 8 == 7) &&
				(s_data_fifo_tx_empty == 1'b0)) ? s_spi_clk_ce2 : 1'b0;
			
			/* If every bit from the FIFO according to i_tx_len value captured
			   in s_tx_len_aux, then move to either WAIT, RX, or STOP. */
			if (s_t == (8 * s_tx_len_aux) - c_t_inc)
				if (s_rx_len_aux > 0)
					if (s_wait_cyc_aux > 0)
						s_spi_nx_state = ST_STAND_WAIT;
					else
						s_spi_nx_state = ST_STAND_RX;
				else
					s_spi_nx_state = ST_STAND_STOP_S;
			else
				s_spi_nx_state = ST_STAND_TX;
		end

		ST_STAND_WAIT: begin
			/* run clock at Mode 0 */
			eo_sck_o = s_spi_clk_1x;
			eo_sck_t = 1'b0;
			/* assert chip select */
			eo_csn_o = 1'b0;
			eo_csn_t = 1'b0;
			/* zero value for COPI */
			eo_copi_o = 1'b0;
			eo_copi_t = 1'b0;
			/* hold not reading the TX FIFO */
			s_data_fifo_tx_re = 1'b0;
			/* machine is not idle */
			s_spi_idle = 1'b0;

			if (s_t == s_wait_cyc_aux - c_t_inc) s_spi_nx_state = ST_STAND_RX;
			else s_spi_nx_state = ST_STAND_WAIT;
		end

		ST_STAND_RX: begin
			/* run clock at Mode 0 */
			eo_sck_o = s_spi_clk_1x;
			eo_sck_t = 1'b0;
			/* assert chip select */
			eo_csn_o = 1'b0;
			eo_csn_t = 1'b0;
			/* zero value for COPI */
			eo_copi_o = 1'b0;
			eo_copi_t = 1'b0;
			/* hold not reading the TX FIFO */
			s_data_fifo_tx_re = 1'b0;
			/* machine is not idle */
			s_spi_idle = 1'b0;

			if (s_t == (8 * s_rx_len_aux) - c_t_inc)
				s_spi_nx_state = ST_STAND_STOP_S;
			else s_spi_nx_state = ST_STAND_RX;			
		end

		ST_STAND_STOP_S: begin
			/* halt clock at Mode 0 */
			eo_sck_o = 1'b0;
			eo_sck_t = 1'b0;
			/* assert chip select */
			eo_csn_o = 1'b0;
			eo_csn_t = 1'b0;
			/* zero value for COPI */
			eo_copi_o = 1'b0;
			eo_copi_t = 1'b0;
			/* hold not reading the TX FIFO */
			s_data_fifo_tx_re = 1'b0;
			/* machine is not idle */
			s_spi_idle = 1'b0;

			if (s_t == c_t_stand_wait_ss - c_t_inc)
				s_spi_nx_state = ST_STAND_STOP_D;
			else s_spi_nx_state = ST_STAND_STOP_S;			
		end

		ST_STAND_STOP_D: begin
			/* halt clock at Mode 0 */
			eo_sck_o = 1'b0;
			eo_sck_t = 1'b0;
			/* no chip select */
			eo_csn_o = 1'b1;
			eo_csn_t = 1'b0;
			/* zero value for COPI */
			eo_copi_o = 1'b0;
			eo_copi_t = 1'b0;
			/* hold not reading the TX FIFO */
			s_data_fifo_tx_re = 1'b0;
			/* machine is not idle */
			s_spi_idle = 1'b0;

			if (s_t == c_t_stand_wait_ss - c_t_inc)
				s_spi_nx_state = ST_STAND_IDLE;
			else s_spi_nx_state = ST_STAND_STOP_D;			
		end

		default: begin // ST_STAND_IDLE
			/* halt clock at Mode 0 */
			eo_sck_o = 1'b0;
			eo_sck_t = 1'b0;
			/* no chip select */
			eo_csn_o = 1'b1;
			eo_csn_t = 1'b0;
			/* zero value for COPI */
			eo_copi_o = 1'b0;
			eo_copi_t = 1'b0;
			/* hold not reading the TX FIFO */
			s_data_fifo_tx_re = 1'b0;
			/* machine is idle */
			s_spi_idle = 1'b1;

			if (s_go_stand) s_spi_nx_state = ST_STAND_START_D;
			else s_spi_nx_state = ST_STAND_IDLE;	
		end
	endcase
end

/* Captures the RX inputs into the RX fifo.
   Note that the RX inputs are delayed by 3 clk_4x clock cycles
   before the delay, the falling edge would occur at the capture of
   clock enable 0; but with the delay of registering output and double
   registering input, the FSM state is delayed by 3 clock cycles for
   RX only and the clock enable to process on the effective falling edge of
   the bus SCK as perceived from propagation out and back in, is 3 clock
   cycles, thus CE 3 instead of CE 0. */
always @(posedge i_ext_spi_clk_x)
begin: p_spi_fsm_inputs
	if (i_srst) begin
		s_data_fifo_rx_we <= 1'b0;
		s_data_fifo_rx_in <= 8'h00;
	end else
		if (s_spi_clk_ce3)
			if (s_spi_pr_state_delayed3 == ST_STAND_RX) begin
				/* input current byte to enqueue, one bit at a time, shifting */
				s_data_fifo_rx_in <= (s_t_delayed3 < (8 * s_rx_len_aux)) ?
					{s_data_fifo_rx_in[6-:7], ei_cipo_i} : 8'h00;

				/* only if on last bit, enqueue another byte */
				/* only if RX FIFO is not full, enqueue another byte */
				s_data_fifo_rx_we = ((s_t_delayed3 % 8 == 7) &&
					(s_data_fifo_rx_full == 1'b0)) ? 1'b1 : 1'b0;
			end else begin
				s_data_fifo_rx_we <= 1'b0;
				s_data_fifo_rx_in <= 8'h00;
			end
		else begin
			s_data_fifo_rx_we <= 1'b0;
			s_data_fifo_rx_in <= s_data_fifo_rx_in;
		end
end

endmodule
//------------------------------------------------------------------------------
