/*------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020-2021 Timothy Stotts
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
-- \file uart_tx_feed.sv
--
-- \brief A simple text byte feeder to the UART TX module.
------------------------------------------------------------------------------*/
`begin_keywords "1800-2009"
//Recursive Moore Machine-------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module uart_tx_feed
	(
		input logic i_clk_20mhz,
		input logic i_rst_20mhz,
		output logic [7:0] o_tx_data,
		output logic o_tx_valid,
		input logic i_tx_ready,
		input logic i_tx_go,
		input logic [(34*8-1):0] i_dat_ascii_line
	);

//Part 2: Declarations----------------------------------------------------------
timeunit 1ns;
timeprecision 1ps;

/* UART TX update FSM state declarations */
`define c_uarttx_feed_fsm_bits 2

typedef enum logic [(`c_uarttx_feed_fsm_bits - 1):0] {
	ST_UARTFEED_IDLE, ST_UARTFEED_CAPT, ST_UARTFEED_DATA, ST_UARTFEED_WAIT
} t_uartfeed_state;

t_uartfeed_state s_uartfeed_pr_state;
t_uartfeed_state s_uartfeed_nx_state;

localparam [5:0] c_uart_k_preset = 34;

localparam [(34*8-1):0] c_line_of_spaces = 
	272'h20202020202020202020202020202020202020202020202020202020202020200D0A;

/* UART TX signals for UART TX update FSM */
logic [5:0] s_uart_k_val;
logic [5:0] s_uart_k_aux;
logic [(34*8-1):0] s_uart_line_val;
logic [(34*8-1):0] s_uart_line_aux;

//Part 3: Statements------------------------------------------------------------
/* UART TX machine, the 34 bytes of \ref s_uart_dat_ascii_line
   are feed into the UART TX ONLY FIFO upon every pulse of the
   \ref s_uart_tx_go signal. The UART TX ONLY FIFO machine will
   automatically dequeue any bytes present in the queue and quickly
   transmit them, one-at-a-time at the \ref parm_BAUD baudrate. */

/* UART TX machine, synchronous state and auxiliary counting register. */
always_ff @(posedge i_clk_20mhz)
begin: p_uartfeed_fsm_state_aux
	if (i_rst_20mhz) begin
		s_uartfeed_pr_state <= ST_UARTFEED_IDLE;
		s_uart_k_aux <= 0;
		s_uart_line_aux <= c_line_of_spaces;
	end
	else begin : if_fsm_state_and_storage
		s_uartfeed_pr_state <= s_uartfeed_nx_state;

		s_uart_k_aux <= s_uart_k_val;
		s_uart_line_aux <= s_uart_line_val;
	end : if_fsm_state_and_storage
end : p_uartfeed_fsm_state_aux

/* UART TX machine, combinatorial next state and auxiliary counting register, and
   auxiliary 34 8-bit character line register. */
always_comb
begin: p_uartfeed_fsm_nx_out
	case (s_uartfeed_pr_state)
		ST_UARTFEED_CAPT: begin
			/* Capture the input ASCII line and the index K.
			   The value of \ref i_tx_ready is also checked as to
			   not overflow the UART TX buffer. Once TX is ready,
			   begin the enqueue of outgoing data. */
			o_tx_data = 8'h00;
			o_tx_valid = 1'b0;
			s_uart_k_val = c_uart_k_preset;
			s_uart_line_val = i_dat_ascii_line;

			if (i_tx_ready) s_uartfeed_nx_state = ST_UARTFEED_DATA;
			else s_uartfeed_nx_state = ST_UARTFEED_CAPT;
		end
		ST_UARTFEED_DATA: begin
			/* Enqueue the \ref c_uart_k_preset count of bytes from register
			   \ref s_uart_line_aux. Then transition to the WAIT state.
			   To accomplish this, s_uart_line_aux is shifted left, one byte
			   at-a-time. */
			o_tx_data = s_uart_line_aux[((8*c_uart_k_preset)-1)-:8];
			o_tx_valid = 1'b1;
			s_uart_k_val = s_uart_k_aux - 1;
			s_uart_line_val = {s_uart_line_aux[(8*(c_uart_k_preset-1)-1)-:(8*(c_uart_k_preset-1))],8'h00};

			if (s_uart_k_aux == 1) s_uartfeed_nx_state = ST_UARTFEED_WAIT;
			else s_uartfeed_nx_state = ST_UARTFEED_DATA;
		end
		ST_UARTFEED_WAIT: begin
			/* Wait for the \ref i_tx_go pulse to be low, and then
			   transition to the IDLE state. */
			o_tx_data = 8'h00;
			o_tx_valid = 1'b0;
			s_uart_k_val = s_uart_k_aux;
			s_uart_line_val = s_uart_line_aux;

			if (! i_tx_go) s_uartfeed_nx_state = ST_UARTFEED_IDLE;
			else s_uartfeed_nx_state = ST_UARTFEED_WAIT;
		end
		default: begin // ST_UARTFEED_IDLE
			/* IDLE the FSM while waiting for a pulse on \ref i_tx_go . */
			o_tx_data = 8'h00;
			o_tx_valid = 1'b0;
			s_uart_k_val = s_uart_k_aux;
			s_uart_line_val = s_uart_line_aux;
			if (i_tx_go) s_uartfeed_nx_state = ST_UARTFEED_CAPT;
			else s_uartfeed_nx_state = ST_UARTFEED_IDLE;
		end
	endcase
end : p_uartfeed_fsm_nx_out

endmodule : uart_tx_feed
//------------------------------------------------------------------------------
`end_keywords
