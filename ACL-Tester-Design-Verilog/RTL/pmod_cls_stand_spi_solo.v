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
-- \file pmod_cls_stand_spi_solo.v
--
-- \brief A SPI interface to Digilent Inc. PMOD CLS lcd display operating in
-- SPI Mode 0. The design only enables clearing the display, or writing a full
-- sixteen character line of one of the two lines of the display at a time.
------------------------------------------------------------------------------*/
//------------------------------------------------------------------------------
//Recursive Moore Machine
//Part 1: Module header:--------------------------------------------------------
module pmod_cls_stand_spi_solo(
	/* system clock and synchronous reset */
	i_ext_spi_clk_x, i_srst, i_spi_ce_4x,
	/* system interface to the \ref pmod_generic_spi_solo module. */
	o_go_stand, i_spi_idle, o_tx_len, o_wait_cyc, o_rx_len,
	/* TX FIFO interface to the \ref pmod_generic_spi_solo module. */
	o_tx_data, o_tx_enqueue, i_tx_ready,
	/* RX FIFO interface to the \ref pmod_generic_spi_solo module. */
	i_rx_data, o_rx_dequeue, i_rx_valid, i_rx_avail,
	/* FPGA system interface to CLS operation */
	o_command_ready,
	i_cmd_wr_clear_display,
	i_cmd_wr_text_line1,
	i_cmd_wr_text_line2,
	i_dat_ascii_line1,
	i_dat_ascii_line2);

/* Disable or enable fast FSM delays for simulation instead of impelementation. */
parameter integer parm_fast_simulation = 0;
/* Actual frequency in Hz of \ref i_ext_spi_clk_4x */
parameter integer FCLK = 20000000;
/* Actual frequency in Hz of \ref i_ext_spi_clk_4x */
parameter integer FCLK_ce = 2500000;
/* LOG2 of the TX FIFO max count */
parameter parm_tx_len_bits = 11;
/* LOG2 of max Wait Cycles count between end of TX and start of RX */
parameter parm_wait_cyc_bits = 2;
/* LOG2 of the RX FIFO max count */
parameter parm_rx_len_bits = 11;

input wire i_ext_spi_clk_x;
input wire i_srst;
input wire i_spi_ce_4x;

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
input wire i_cmd_wr_clear_display;
input wire i_cmd_wr_text_line1;
input wire i_cmd_wr_text_line2;
input wire [(16 * 8 - 1):0] i_dat_ascii_line1;
input wire [(16 * 8 - 1):0] i_dat_ascii_line2;

// Part 2: Declarations---------------------------------------------------------
/* Timer signals and constants. */
`define c_cls_drv_time_value_bits 24
/* Boot time should be in hundreds of milliseconds as the PMOD CLS
   datasheet does not indicate boot-up time of the PMOD CLS microcontroller. */
/* This constant can be temporarily changed iby parameter to shorten the
   boot-up time of the project's simulation. */
localparam [(`c_cls_drv_time_value_bits - 1):0] c_t_pmodcls_boot =
	parm_fast_simulation ? (FCLK_ce / 1000 * 2) : (FCLK_ce / 1000 * 800);
localparam [(`c_cls_drv_time_value_bits - 1):0] c_tmax = c_t_pmodcls_boot - 1;

reg [(`c_cls_drv_time_value_bits - 1):0] s_t;

/* Driver FSM state declarations */
`define c_cls_drv_state_bits 4

localparam [(`c_cls_drv_state_bits - 1):0] ST_CLS_BOOT0 = 0;
localparam [(`c_cls_drv_state_bits - 1):0] ST_CLS_IDLE = 1;
localparam [(`c_cls_drv_state_bits - 1):0] ST_CLS_LOAD_CLEAR = 2;
localparam [(`c_cls_drv_state_bits - 1):0] ST_CLS_LOAD_LINE1 = 3;
localparam [(`c_cls_drv_state_bits - 1):0] ST_CLS_LOAD_LINE2 = 4;
localparam [(`c_cls_drv_state_bits - 1):0] ST_CLS_CMD_RUN = 5;
localparam [(`c_cls_drv_state_bits - 1):0] ST_CLS_CMD_WAIT = 6;
localparam [(`c_cls_drv_state_bits - 1):0] ST_CLS_DAT_RUN = 7;
localparam [(`c_cls_drv_state_bits - 1):0] ST_CLS_DAT_WAIT = 8;

/* Xilinx attributes for auto encoding of the FSM and safe state is
   Default State. */
(* fsm_encoding = "auto" *)
(* fsm_safe_state = "default_state" *)
reg [(`c_cls_drv_state_bits - 1):0] s_cls_drv_pr_state = ST_CLS_BOOT0;
reg [(`c_cls_drv_state_bits - 1):0] s_cls_drv_nx_state = ST_CLS_BOOT0;

/* Auxiliary state machine registers for recursive state machine operation. */
reg [3:0] s_cls_cmd_len_aux;
reg [3:0] s_cls_cmd_len_val;
reg [4:0] s_cls_dat_len_aux;
reg [4:0] s_cls_dat_len_val;
reg [55:0] s_cls_cmd_tx_aux;
reg [55:0] s_cls_cmd_tx_val;
reg [4:0] s_cls_cmd_txlen_aux;
reg [4:0] s_cls_cmd_txlen_val;
reg [127:0] s_cls_dat_tx_aux;
reg [127:0] s_cls_dat_tx_val;
reg [5:0] s_cls_dat_txlen_aux;
reg [5:0] s_cls_dat_txlen_val;

/* ASCII constant characters for ESC codes. */
localparam [7:0] ASCII_CLS_ESC = 8'h1b;
localparam [7:0] ASCII_CLS_BRACKET = 8'h5b;
localparam [7:0] ASCII_CLS_CHAR_ZERO = 8'h30;
localparam [7:0] ASCII_CLS_CHAR_SEMICOLON = 8'h3b;
localparam [7:0] ASCII_CLS_DISP_CLR_CMD = 8'h6a;
localparam [7:0] ASCII_CLS_CURSOR_POS_CMD = 8'h48;

//Part 3: Statements------------------------------------------------------------

/* Timer 1 (Strategy #1), for timing the boot wait for PMOD CLS communication */
always @(posedge i_ext_spi_clk_x)
begin: p_timer_1
	if (i_srst) s_t <= 0;
	else
		if (i_spi_ce_4x) begin
			if (s_cls_drv_pr_state != s_cls_drv_nx_state) s_t <= 0;
			else if (s_t < c_tmax) s_t <= s_t + 1;
		end
end

/* FSM state register plus auxiliary registers, for propagating the next state
   as well as the next recursive auxiliary register value for use within
   one or more state combinatorial logic decisions. */
always @(posedge i_ext_spi_clk_x)
begin: p_fsm_state_aux
	if (i_srst) begin
		s_cls_drv_pr_state <= ST_CLS_BOOT0;

		s_cls_cmd_len_aux <= 4'd0;
		s_cls_dat_len_aux <= 5'd0;
		s_cls_cmd_tx_aux <= 56'd0;
		s_cls_dat_tx_aux <= 128'd0;
		s_cls_cmd_txlen_aux <= 0;
		s_cls_dat_txlen_aux <= 0;
	end else
		if (i_spi_ce_4x) begin
			s_cls_drv_pr_state <= s_cls_drv_nx_state;

			s_cls_cmd_len_aux <= s_cls_cmd_len_val;
			s_cls_dat_len_aux <= s_cls_dat_len_val;
			s_cls_cmd_tx_aux <= s_cls_cmd_tx_val;
			s_cls_dat_tx_aux <= s_cls_dat_tx_val;
			s_cls_cmd_txlen_aux <= s_cls_cmd_txlen_val;
			s_cls_dat_txlen_aux <= s_cls_dat_txlen_val;
		end
end


/* FSM combinatorial logic providing multiple outputs, assigned in every state,
   as well as changes in auxiliary values, and calculation of the next FSM
   state. Refer to the FSM state machine drawings in document:
   \ref exercise-14-10-drawing.pdf . */
always @(s_cls_drv_pr_state,
	s_cls_cmd_len_aux, s_cls_dat_len_aux, s_cls_cmd_tx_aux, s_cls_dat_tx_aux,
	s_cls_cmd_txlen_aux, s_cls_dat_txlen_aux,
	s_t,
	i_cmd_wr_clear_display, i_cmd_wr_text_line1, i_cmd_wr_text_line2,
	i_dat_ascii_line1, i_dat_ascii_line2,
	i_tx_ready, i_spi_idle)
begin: p_fsm_comb
	case (s_cls_drv_pr_state)
		ST_CLS_LOAD_CLEAR: begin
			/* Load the 4-byte ASCII escape sequence for clearing the display into
			   the \ref s_cls_cmd_tx_aux auxiliary register, and load nothing into
			   the \ref s_cls_dat_tx_aux auxiliary register for additional data
			   transfer. */
			o_command_ready = 1'b0;
			o_tx_data = 8'h00;
			o_tx_enqueue = 1'b0;
			o_tx_len = 0;
			o_rx_len = 0;
			o_wait_cyc = 0;
			o_rx_dequeue = 1'b0;
			o_go_stand = 1'b0;
			s_cls_cmd_len_val = 4;
			s_cls_cmd_tx_val = {24'h000000,
				ASCII_CLS_ESC,
				ASCII_CLS_BRACKET,
				ASCII_CLS_CHAR_ZERO,
				ASCII_CLS_DISP_CLR_CMD};
			s_cls_dat_len_val = 0;
			s_cls_dat_tx_val = 128'd0;
			s_cls_cmd_txlen_val = 4;
			s_cls_dat_txlen_val = 0;

			s_cls_drv_nx_state = ST_CLS_CMD_RUN;
		end

		ST_CLS_LOAD_LINE1: begin
			/* Load the 7-byte ASCII escape sequence for writing display line 1 into
			   the \ref s_cls_cmd_tx_aux auxiliary register, and load the 16-byte text into
			   the \ref s_cls_dat_tx_aux auxiliary register for additional data transfer. */
			o_command_ready = 1'b0;
			o_tx_data = 8'h00;
			o_tx_enqueue = 1'b0;
			o_tx_len = 0;
			o_rx_len = 0;
			o_wait_cyc = 0;
			o_rx_dequeue = 1'b0;
			o_go_stand = 1'b0;
			s_cls_cmd_len_val = 7;
			s_cls_cmd_tx_val = {
				ASCII_CLS_ESC,
				ASCII_CLS_BRACKET,
				ASCII_CLS_CHAR_ZERO, 
				ASCII_CLS_CHAR_SEMICOLON,
				ASCII_CLS_CHAR_ZERO,
				ASCII_CLS_CHAR_ZERO,
				ASCII_CLS_CURSOR_POS_CMD};
			s_cls_dat_len_val = 16;
			s_cls_dat_tx_val = i_dat_ascii_line1;
			s_cls_cmd_txlen_val = 7;
			s_cls_dat_txlen_val = 16;

			s_cls_drv_nx_state = ST_CLS_CMD_RUN;
		end

		ST_CLS_LOAD_LINE2: begin
			/* Load the 7-byte ASCII escape sequence for writing display line 2 into
			   the \ref s_cls_cmd_tx_aux auxiliary register, and load the 16-byte text into
			   the \ref s_cls_dat_tx_aux auxiliary register for additional data transfer. */
			o_command_ready = 1'b0;
			o_tx_data = 8'h00;
			o_tx_enqueue = 1'b0;
			o_tx_len = 0;
			o_rx_len = 0;
			o_wait_cyc = 0;
			o_rx_dequeue = 1'b0;
			o_go_stand = 1'b0;
			s_cls_cmd_len_val = 7;
			s_cls_cmd_tx_val = {
				ASCII_CLS_ESC,
				ASCII_CLS_BRACKET,
				(ASCII_CLS_CHAR_ZERO + 8'd1), 
				ASCII_CLS_CHAR_SEMICOLON,
				ASCII_CLS_CHAR_ZERO,
				ASCII_CLS_CHAR_ZERO,
				ASCII_CLS_CURSOR_POS_CMD};
			s_cls_dat_len_val = 16;
			s_cls_dat_tx_val = i_dat_ascii_line2;
			s_cls_cmd_txlen_val = 7;
			s_cls_dat_txlen_val = 16;

			s_cls_drv_nx_state = ST_CLS_CMD_RUN;
		end

		ST_CLS_CMD_RUN: begin
			/* Run the loading into the SPI TX FIFO of the command from the
			   \ref s_cls_cmd_tx_aux auxiliary register, and then on the
			   loading of the last byte, command the SPI operation to start. */
			o_command_ready = 1'b0;
			o_tx_data = s_cls_cmd_tx_aux[((s_cls_cmd_len_aux * 8) - 1) -: 8];
			o_tx_enqueue = i_tx_ready;
			o_tx_len = s_cls_cmd_txlen_aux;
			o_rx_len = 0;
			o_wait_cyc = 0;
			o_rx_dequeue = 1'b0;
			o_go_stand = (s_cls_cmd_len_aux > 1) ? 1'b0 : (i_tx_ready ? 1'b1 : 1'b0);
			s_cls_cmd_len_val = i_tx_ready ? (s_cls_cmd_len_aux - 1) : s_cls_cmd_len_aux;
			s_cls_cmd_tx_val = s_cls_cmd_tx_aux;
			s_cls_dat_len_val = s_cls_dat_len_aux;
			s_cls_dat_tx_val = s_cls_dat_tx_aux;
			s_cls_cmd_txlen_val = s_cls_cmd_txlen_aux;
			s_cls_dat_txlen_val = s_cls_dat_txlen_aux;

			if ((i_tx_ready == 1'b1) && (s_cls_cmd_len_aux <= 1))
				s_cls_drv_nx_state = ST_CLS_CMD_WAIT;
			else
				s_cls_drv_nx_state = ST_CLS_CMD_RUN;
		end

		ST_CLS_CMD_WAIT: begin
			/* Wait for the command sequence to end and for the SPI operation
			   to return to IDLE. */
			o_command_ready = 1'b0;
			o_tx_enqueue = 1'b0;
			o_tx_data = 8'h00;
			o_tx_len = 0;
			o_rx_len = 0;
			o_wait_cyc = 0;
			o_rx_dequeue = 1'b0;
			o_go_stand = 1'b0;
			s_cls_cmd_len_val = s_cls_cmd_len_aux;
			s_cls_cmd_tx_val = s_cls_cmd_tx_aux;
			s_cls_dat_len_val = s_cls_dat_len_aux;
			s_cls_dat_tx_val = s_cls_dat_tx_aux;
			s_cls_cmd_txlen_val = s_cls_cmd_txlen_aux;
			s_cls_dat_txlen_val = s_cls_dat_txlen_aux;

			if (i_spi_idle)
				if (s_cls_dat_txlen_aux > 0)
					s_cls_drv_nx_state = ST_CLS_DAT_RUN;
				else
					s_cls_drv_nx_state = ST_CLS_IDLE;
			else
				s_cls_drv_nx_state = ST_CLS_CMD_WAIT;
		end

		ST_CLS_DAT_RUN: begin
			/* Run the loading into the SPI TX FIFO of the data from the
			   \ref s_cls_dat_tx_aux auxiliary register, and then on the
			   loading of the last byte, command the SPI operation to start. */
			o_command_ready = 1'b0;
			o_tx_data = s_cls_dat_tx_aux[((s_cls_dat_len_aux * 8) - 1) -: 8];
			o_tx_enqueue = i_tx_ready;
			o_tx_len = s_cls_dat_txlen_aux;
			o_rx_len = 0;
			o_wait_cyc = 0;
			o_rx_dequeue = 1'b0;
			o_go_stand = (s_cls_dat_len_aux > 1) ? 1'b0 : (i_tx_ready ? 1'b1 : 1'b0);
			s_cls_cmd_len_val = s_cls_cmd_len_aux;
			s_cls_dat_len_val = i_tx_ready ? (s_cls_dat_len_aux - 1) : s_cls_dat_len_aux;
			s_cls_cmd_tx_val = s_cls_cmd_tx_aux;
			s_cls_dat_tx_val = s_cls_dat_tx_aux;
			s_cls_cmd_txlen_val = s_cls_cmd_txlen_aux;
			s_cls_dat_txlen_val = s_cls_dat_txlen_aux;

			if ((i_tx_ready == 1'b1) && (s_cls_dat_len_aux <= 1))
				s_cls_drv_nx_state = ST_CLS_DAT_WAIT;
			else
				s_cls_drv_nx_state = ST_CLS_DAT_RUN;
		end

		ST_CLS_DAT_WAIT: begin
			/* Wait for the data sequence to end and for the SPI operation
			   to return to IDLE. */
			o_command_ready = 1'b0;
			o_tx_enqueue = 1'b0;
			o_tx_data = 8'h00;
			o_tx_len = 0;
			o_rx_len = 0;
			o_wait_cyc = 0;
			o_rx_dequeue = 1'b0;
			o_go_stand = 1'b0;
			s_cls_cmd_len_val = s_cls_cmd_len_aux;
			s_cls_cmd_tx_val = s_cls_cmd_tx_aux;
			s_cls_dat_len_val = s_cls_dat_len_aux;
			s_cls_dat_tx_val = s_cls_dat_tx_aux;
			s_cls_cmd_txlen_val = s_cls_cmd_txlen_aux;
			s_cls_dat_txlen_val = s_cls_dat_txlen_aux;

			if (i_spi_idle) s_cls_drv_nx_state = ST_CLS_IDLE;
			else s_cls_drv_nx_state = ST_CLS_DAT_WAIT;
		end

		ST_CLS_IDLE: begin
			/* IDLE the PMOD CLS driver FSM and wait for one of the three commands:
			   (a) clear the display
			   (b) write display text line 1
			   (c) write display text line 2 */
			o_command_ready = 1'b1;
			o_tx_enqueue = 1'b0;
			o_tx_data = 8'h00;
			o_tx_len = 0;
			o_rx_len = 0;
			o_wait_cyc = 0;
			o_rx_dequeue = 1'b0;
			o_go_stand = 1'b0;
			s_cls_cmd_len_val = s_cls_cmd_len_aux;
			s_cls_cmd_tx_val = s_cls_cmd_tx_aux;
			s_cls_dat_len_val = s_cls_dat_len_aux;
			s_cls_dat_tx_val = s_cls_dat_tx_aux;
			s_cls_cmd_txlen_val = s_cls_cmd_txlen_aux;
			s_cls_dat_txlen_val = s_cls_dat_txlen_aux;

			if (i_cmd_wr_clear_display) s_cls_drv_nx_state = ST_CLS_LOAD_CLEAR;
			else if (i_cmd_wr_text_line1) s_cls_drv_nx_state = ST_CLS_LOAD_LINE1;
			else if (i_cmd_wr_text_line2) s_cls_drv_nx_state = ST_CLS_LOAD_LINE2;
			else s_cls_drv_nx_state = ST_CLS_IDLE;
		end

		default: begin // ST_CLS_BOOT0
			/* The datasheet for the PMOD CLS does not indicate the boot-up time
			   required for the PMOD CLS microcontroller. At boot-up, wait a
			   a time of \ref c_t_pmodcls_boot before accepting commands to operate
			   the PMOD CLS display. */
			o_command_ready = 1'b0;
			o_tx_data = 8'h00;
			o_tx_enqueue = 1'b0;
			o_tx_len = 0;
			o_rx_len = 0;
			o_wait_cyc = 0;
			o_rx_dequeue = 1'b0;
			o_go_stand = 1'b0;
			s_cls_cmd_len_val = s_cls_cmd_len_aux;
			s_cls_cmd_tx_val = s_cls_cmd_tx_aux;
			s_cls_dat_len_val = s_cls_dat_len_aux;
			s_cls_dat_tx_val = s_cls_dat_tx_aux;
			s_cls_cmd_txlen_val = s_cls_cmd_txlen_aux;
			s_cls_dat_txlen_val = s_cls_dat_txlen_aux;

			if (s_t == c_t_pmodcls_boot - 1) s_cls_drv_nx_state = ST_CLS_IDLE;
			else s_cls_drv_nx_state = ST_CLS_BOOT0;
		end
	endcase
end

endmodule
//------------------------------------------------------------------------------
