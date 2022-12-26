/*------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020-2022 Timothy Stotts
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
-- \file ext_interrupt_debouncer.sv
--
-- \brief A simple 1 microsecond signal synchronizer and debouncer to filter-out
--        glitches on an external Interrupt line from an external Integrated
--        Circuit.
------------------------------------------------------------------------------*/
`begin_keywords "1800-2012"
//Timed Moore machine with timer control strategy #1
//Part 1: Module header:--------------------------------------------------------
module ext_interrupt_debouncer(
	output logic o_int_deb,
	input logic i_clk_20mhz,
	input logic i_rst_20mhz,
	input logic ei_interrupt);

// Part 2: Declarations---------------------------------------------------------
timeunit 1ns;
timeprecision 1ps;

// Debouncer FSM states.
`define c_intdeb_state_bits 2

// Xilinx attributes for Gray encoding of the FSM and safe state is Default
// State.
/* FSM state signals for Present and Next. */
(* fsm_encoding = "gray" *)
(* fsm_safe_state = "default_state" *)
typedef enum logic [(`c_intdeb_state_bits - 1):0] {
	ST_A, ST_B, ST_C, ST_D} t_intdeb_state;
t_intdeb_state s_intdeb_pr_state;
t_intdeb_state s_intdeb_nx_state;

// Debouncer Timer parameters.
`define c_intdeb_timer1_bits 5
localparam [(`c_intdeb_timer1_bits - 1):0] c_t1 = 20; /* 1 microsecond time at 20 MHz */
localparam [(`c_intdeb_timer1_bits - 1):0] c_tmax = c_t1 - 1;

// Strategy #1 timer implementation.
logic [(`c_intdeb_timer1_bits - 1):0] s_t;

// Resulting debounced interrupt signal.
logic s_int_deb;

// Variables for synchronizing the external interrupt input signal.
logic si_interrupt_meta;
logic si_interrupt_sync;

//Part 3: Statements------------------------------------------------------------

// Input synchronizer to mitigate metastability on the interrupt input. This is
// actually necessary as a metastable input into the FSM LUT and FF synthesized
// encoding could cause more than one location of the input value to be
// interpreted differently, causing the FSM to produce invalid behavior, (not
// according to design).
always_ff @(posedge i_clk_20mhz)
begin: p_sync_interrupt
	si_interrupt_sync <= si_interrupt_meta;
	si_interrupt_meta <= ei_interrupt;
end : p_sync_interrupt

// Timer with strategy #1 implementation. The timer re-zeroes on a debouncer FSM
// state transition; and it caps at the constant parameter c_tmax.
always_ff @(posedge i_clk_20mhz)
begin: p_fsm_timer
	if (i_rst_20mhz)
		s_t <= 0;
	else
		if (s_intdeb_pr_state != s_intdeb_nx_state) begin : if_chg_state
			s_t <= 0;
		end : if_chg_state

		else if (s_t != c_tmax) begin : if_not_timer_max
			s_t <= s_t + 1;
		end : if_not_timer_max

end : p_fsm_timer

// FSM state register for transition of the FSM next state propagating to
// current state, on the positive edge of the clock.
always_ff @(posedge i_clk_20mhz)
begin: p_fsm_state
	if (i_rst_20mhz)
		s_intdeb_pr_state <= ST_A;
	else
		s_intdeb_pr_state <= s_intdeb_nx_state;
end : p_fsm_state

// FSM combinatorial logic providing a single output value \ref s_int_deb,
// as well as setting-up the next state value to propagate on the next
// positive clock edge.
always_comb
begin: p_fsm_nx_output
	case (s_intdeb_pr_state)
		ST_B: begin
			// State B. Hold the debounced signal at zero. If the stable input ever
			// transitions back to zero, then transition back to State A. If the
			// timer elapses for a full duration of the signal being one, then
			// transition the state to State C.
			s_int_deb = 1'b0;
			if (! si_interrupt_sync) s_intdeb_nx_state = ST_A;
			else if (s_t >= c_t1 - 2) s_intdeb_nx_state = ST_C;
			else s_intdeb_nx_state = ST_B;
		end
		ST_C: begin
			// State C. Hold the debounced signal at one. If the stable input value
			// transitions to zero, then transition to State D to count a timer
			// time while waiting to change the debounced output to zero.
			s_int_deb = 1'b1;
			if (! si_interrupt_sync) s_intdeb_nx_state = ST_D;
			else s_intdeb_nx_state = ST_C;
		end
		ST_D: begin
			// State D. Hold the debounced signal at one. If the stable input ever
			// transitions back to one, then transition back to State C. If the
			// timer elapses for a full duration of the signal being zero, then
			// transition the state to State A.
			s_int_deb = 1'b1;
			if (si_interrupt_sync) s_intdeb_nx_state = ST_C;
			else if (s_t >= c_t1 - 2) s_intdeb_nx_state = ST_A;
			else s_intdeb_nx_state = ST_D;
		end
		default: begin // ST_A
			// State A. Hold the debounced signal at zero. If the stable input value
			// transitions to one, then transition to State B to count a timer
			// time while waiting to change the debounced output to one.
			s_int_deb = 1'b0;
			if (si_interrupt_sync) s_intdeb_nx_state = ST_B;
			else s_intdeb_nx_state = ST_A;
		end
	endcase
end : p_fsm_nx_output

// The debounced interrupt produced by the combinatorial logic is output here
// without an extra registration.
assign o_int_deb = s_int_deb;

endmodule
//------------------------------------------------------------------------------
`end_keywords
