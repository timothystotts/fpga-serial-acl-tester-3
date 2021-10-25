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
-- \file clock_enable_divider.v
--
-- \brief A clock enable divider for an integer division of the source
-- clock enable. The clock and synchronous reset are kept the same; but the
-- clock enable is further divided.
------------------------------------------------------------------------------*/
//------------------------------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module clock_enable_divider(o_ce_div, i_clk_mhz, i_rst_mhz, i_ce_mhz);
parameter integer par_ce_divisor = 1000;
output wire o_ce_div;
input wire i_clk_mhz;
input wire i_rst_mhz;
input wire i_ce_mhz;

// Part 2: Declarations---------------------------------------------------------
/* A constant representing the counter maximum which is an even division of the
   source clock, per paramter \ref par_ce_divisor . */
localparam integer c_clk_max = par_ce_divisor - 1;

/* Clock division count, that counts from 0 to \ref c_clk_max and back again
   to run the divided clock enable output at a division of i_clk_mhz according
   to a down division ratio of \ref i_ce_mhz
   the source clock. */
integer s_clk_div_cnt;

/* A clock enable at the source clock frequency which issues the periodic
   toggle of the divided clock. */
reg s_clk_div_ce;

//Part 3: Statements------------------------------------------------------------
/* The even clock frequency division is operated by a clock enable signal to
   indicate the upstream clock cycle for changing the edge of the downstream
   clock enable waveform. */
always @(posedge i_clk_mhz)
begin: p_clk_div_cnt
	if (i_rst_mhz) begin
		s_clk_div_cnt <= 0;
		s_clk_div_ce <= 1'b1;
	end else
		if (i_ce_mhz)
			if (s_clk_div_cnt == c_clk_max) begin
				s_clk_div_cnt <= 0;
				s_clk_div_ce <= 1'b1;
			end else begin
				s_clk_div_cnt <= s_clk_div_cnt + 1;
				s_clk_div_ce <= 1'b0;
			end
		else begin
			s_clk_div_cnt <= s_clk_div_cnt;
			s_clk_div_ce <= 1'b0;
		end
end

assign o_ce_div = s_clk_div_ce;

endmodule
//------------------------------------------------------------------------------
