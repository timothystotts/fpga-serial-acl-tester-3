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
-- \file multi_input_debounce.v
--
-- \module multi_input_debounce
--
-- \brief This FSM is the full 4-button mutual-exclusive debouncer, level
-- output, without embedded one-shot, with 1 millisecond debounce.
------------------------------------------------------------------------------*/
//------------------------------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module multi_input_debounce(i_clk_mhz, i_rst_mhz, ei_buttons, o_btns_deb);

parameter integer FCLK = 20000000;

input wire i_clk_mhz;
input wire i_rst_mhz;
input wire [3:0] ei_buttons;
output wire [3:0] o_btns_deb;

//Part 2: Declarations----------------------------------------------------------
localparam [1:0] ST_A = 0;
localparam [1:0] ST_B = 1;
localparam [1:0] ST_C = 2;
localparam [1:0] ST_D = 3;

(* fsm_encoding = "auto" *)
(* fsm_safe_state = "default_state" *)
reg [1:0] s_pr_state;
reg [1:0] s_nx_state;

localparam integer c_T = FCLK * 1 / 1000; // 1 millisecond debounce
localparam integer c_tmax = c_T - 1;

integer s_t;

reg [3:0] si_buttons_meta;
reg [3:0] si_buttons_sync;
reg [3:0] si_buttons_prev;
reg [3:0] si_buttons_store;
reg [3:0] so_btns_deb;

//Part 3: Statements------------------------------------------------------------

// FSM input signals
always @(posedge i_clk_mhz)
begin: p_sync_buttons_input
	si_buttons_sync <= si_buttons_meta;
	si_buttons_meta <= ei_buttons;
end

// FSM Timer (Strategy #1)
always @(posedge i_clk_mhz)
begin: p_fsm_timer1
	if (i_rst_mhz)
		s_t <= 0;
	else
		if (s_pr_state != s_nx_state)
			s_t <= 0;
		else if (s_t != c_tmax)
			s_t <= s_t + 1;
end

// FSM state register:
always @(posedge i_clk_mhz)
begin: p_fsm_state
	if (i_rst_mhz) begin
		s_pr_state <= ST_A;
		si_buttons_prev <= 4'b0000;
		si_buttons_store <= 4'b0000;
	end else begin
		if ((s_nx_state == ST_C) && (s_pr_state == ST_B))
			si_buttons_store <= si_buttons_prev;

		si_buttons_prev <= si_buttons_sync;

		s_pr_state <= s_nx_state;
	end
end

// FSM combinational logic:
always @(s_pr_state, s_t, si_buttons_sync, si_buttons_prev,
	si_buttons_store)
begin: p_fsm_comb
	case (s_pr_state)
		ST_B: begin
			so_btns_deb <= 4'b0000;
			if (si_buttons_sync != si_buttons_prev)
				s_nx_state <= ST_A;
			else if (s_t == c_T - 2)
				s_nx_state <= ST_C;
			else
				s_nx_state <= ST_B;
		end
		ST_C: begin
			so_btns_deb <= si_buttons_store;
			if (si_buttons_sync != si_buttons_store)
				s_nx_state <= ST_D;
			else
				s_nx_state <= ST_C;
		end
		ST_D: begin
			so_btns_deb <= si_buttons_store;
			if (si_buttons_sync == si_buttons_store)
				s_nx_state <= ST_C;
			else if (s_t == c_T - 3)
				s_nx_state <= ST_A;
			else
				s_nx_state <= ST_D;
		end
		default: begin // ST_A
			so_btns_deb <= 4'b0000;
			if ((si_buttons_sync == 4'b0000) ||
				(si_buttons_sync == 4'b1000) ||
				(si_buttons_sync == 4'b0100) ||
				(si_buttons_sync == 4'b0010) ||
				(si_buttons_sync == 4'b0001))
				s_nx_state <= ST_B;
			else
				s_nx_state <= ST_A;
		end
	endcase
end

assign o_btns_deb = so_btns_deb;

endmodule
//------------------------------------------------------------------------------
