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
-- \file one_shot_fsm.sv
--
-- \brief A one-shot pulse generator based on level input.
--
-- \description  This FSM fimplements the FSM of Figure 5.7c from the text
-- Finite State Machines in Hardware: Theory and Design (with VHDL and
-- SystemVerilog) by Volnei A. Pedroni.
------------------------------------------------------------------------------*/
`begin_keywords "1800-2017"
//Regular FSM-------------------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module one_shot_fsm
	(
		input logic x,
		input logic clk,
		input logic rst,
		output logic y
		);

// Part 2: Declarations---------------------------------------------------------
timeunit 1ns;
timeprecision 1ps;

typedef enum logic [1:0] {ST_A, ST_B, ST_C} t_1shot_state;
t_1shot_state s_1shot_pr_state;
t_1shot_state s_1shot_nx_state;

logic s_y_out;

//Part 3: Statements------------------------------------------------------------

// State register
always_ff @(posedge clk)
begin : p_fsm_pr_state
	if (rst) s_1shot_pr_state <= ST_A;
	else s_1shot_pr_state <= s_1shot_nx_state;
end : p_fsm_pr_state

// Next state assignment and output
always_comb
begin : p_fsm_nx_state_out
	case (s_1shot_pr_state)
		ST_B : begin
			s_y_out = 1'b1;
			if (x) s_1shot_nx_state = ST_C;
			else s_1shot_nx_state = ST_A;
		end
		ST_C : begin
			s_y_out = 1'b0;
			if (! x) s_1shot_nx_state = ST_A;
			else s_1shot_nx_state = ST_C;
		end
		default : begin // ST_A
			s_y_out = 1'b0;
			if (x) s_1shot_nx_state = ST_B;
			else s_1shot_nx_state = ST_A;
		end
	endcase // s_1shot_pr_state
end : p_fsm_nx_state_out

// Register output to prevent possible FSM output glitch
always_ff @(posedge clk)
begin : p_fsm_glitch_free
	y <= s_y_out;
end : p_fsm_glitch_free

endmodule : one_shot_fsm // one_shot_fsm_best
//------------------------------------------------------------------------------
`end_keywords
