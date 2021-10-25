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
-- \file pulse_stretcher_synch.v
--
-- \brief A synchronous pulse stretcher implementation
--
-- \description  This FSM for \ref par_T_stretch_count of 2 or more implements
-- the FSM of Figure 8.28a from the text Finite State Machines in Hardware:
-- Theory and Design (with VHDL and SystemVerilog) by Volnei A. Pedroni..
------------------------------------------------------------------------------*/
//Timed Moore machine with timer control strategy #1
//Part 1: Module header:--------------------------------------------------------
module pulse_stretcher_synch(o_y, i_clk, i_rst, i_x);
/* The exact count of clock cycles to hold Y as a one immediately after
   a single clock cycle of X being a value of one. */
parameter integer par_T_stretch_bits = 7; /* LOG2 of \ref par_T_stretch_val */
parameter integer par_T_stretch_val = 64;
/* The stretched output */
output reg o_y;
/* Clock and reset */
input wire i_clk;
input wire i_rst;
/* The input value to stretch upon value of one. */
input wire i_x;

// Part 2: Declarations---------------------------------------------------------
/* Stretcher FSM state values */
localparam [0:0] ST_A = 1'b0;
localparam [0:0] ST_B = 1'b1;

/* Stretcher FSM time constants */
localparam [(par_T_stretch_bits - 1):0] c_t_stretch = par_T_stretch_val;
localparam [(par_T_stretch_bits - 1):0] c_tmax = c_t_stretch - 1;

/* Stretcher FSM state register and next state signal */
(* fsm_encoding = "gray" *)
(* fsm_safe_state = "default_state" *)
reg [0:0] s_stretch_pr_state;
reg [0:0] s_stretch_nx_state;

/* Stretcher FSM timing signal */
reg [(par_T_stretch_bits - 1):0] s_t;

//Part 3: Statements------------------------------------------------------------
//Timer (strategy #1)
always @(posedge i_clk)
begin: p_fsm_timer
	if (i_rst) s_t <= 0;
	else
		// reset and increment the timer
		if (s_stretch_pr_state != s_stretch_nx_state)
			s_t <= 0;
		else if (s_t != c_tmax)
			s_t <= s_t + 1;
end

//FSM state register
always @(posedge i_clk)
begin: p_fsm_state
	if (i_rst) s_stretch_pr_state <= ST_A;
	else s_stretch_pr_state <= s_stretch_nx_state;
end

//FSM combinatorial
always @(s_stretch_pr_state, i_x, s_t)
begin: p_fsm_comb
	case (s_stretch_pr_state)
		ST_B: begin
			/* State B. Hold the output as one and test if the time
			   constant for stretching the output has elapsed. Upon
			   elapse, transition back to State A. */
			o_y = 1'b1;
			if (s_t >= c_t_stretch - 1) s_stretch_nx_state = ST_A;
			else s_stretch_nx_state = ST_B;
		end
		default: begin // ST_A
			/* State A. Hold the output as zero and test if the input
			   has dhanged to one. Upon change, transition to state B. */
			o_y = 1'b0;
			if (i_x) s_stretch_nx_state = ST_B;
			else s_stretch_nx_state = ST_A;
		end
	endcase // s_stretch_pr_state
end

endmodule
//------------------------------------------------------------------------------
