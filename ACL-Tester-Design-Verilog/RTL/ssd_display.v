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
/*------------------------------------------------------------------------------
-- \file ssd_display.v
--
-- \brief A Seven Segment Display driver for a single Pmod SSD. The input is a
-- 8-bit hexademical value which is display as hexadecimal on the Pmod SSD.
------------------------------------------------------------------------------*/
//------------------------------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module two_digit_ssd_out(o_disp0, o_disp1, i_clk_20mhz, i_rst_20mhz, i_value);

output reg [6:0] o_disp0;
output reg [6:0] o_disp1;
input wire i_clk_20mhz;
input wire i_rst_20mhz;
input wire [7:0] i_value;

// Part 2: Declarations---------------------------------------------------------
/* A function to convert a 4-bit hexadecimal value to a single hexadecimal
   digit of a 7-bit 7-segment display of the PMOD SSD. */
function automatic [6:0] unsigned_to_ssd(input [3:0] val);
	case (val)
		4'h0: unsigned_to_ssd = 7'b0111111;
		4'h1: unsigned_to_ssd = 7'b0000110;
		4'h2: unsigned_to_ssd = 7'b1011011;
		4'h3: unsigned_to_ssd = 7'b1001111;
		4'h4: unsigned_to_ssd = 7'b1100110;
		4'h5: unsigned_to_ssd = 7'b1101101;
		4'h6: unsigned_to_ssd = 7'b1111101;
		4'h7: unsigned_to_ssd = 7'b0000111;
		4'h8: unsigned_to_ssd = 7'b1111111;
		4'h9: unsigned_to_ssd = 7'b1100111;
		4'hA: unsigned_to_ssd = 7'b1110111;
		4'hB: unsigned_to_ssd = 7'b1111100;
		4'hC: unsigned_to_ssd = 7'b0111001;
		4'hD: unsigned_to_ssd = 7'b1011110;
		4'hE: unsigned_to_ssd = 7'b1111001;
		4'hF: unsigned_to_ssd = 7'b1110001;
		default: unsigned_to_ssd = 7'b0000000;
	endcase
endfunction

/* The right (LSByte) hexadecimal value. */
wire [3:0] s_value_part0;

/* The left (MSByte) hexadecimal value. */
wire [3:0] s_value_part1;

/* The right segment display value. */
wire [6:0] so_disp0;

/* The left segment display value. */
wire [6:0] so_disp1;

//Part 3: Statements------------------------------------------------------------

/* Convert the value input to lower and upper base sixteen digit. */
assign s_value_part0 = i_value[3-:4];
assign s_value_part1 = i_value[7-:4];

/* Convert the lower and uppper digit to SSD segments */
assign so_disp0 = unsigned_to_ssd(s_value_part0);
assign so_disp1 = unsigned_to_ssd(s_value_part1);

/* Register the combinatorial pre-output */
always @(posedge i_clk_20mhz)
begin: p_reg_out
	if (i_clk_20mhz) begin
		if (i_rst_20mhz) begin
			o_disp0 <= 7'b0000000;
			o_disp1 <= 7'b0000000;
		end else begin
			o_disp0 <= so_disp0;
			o_disp1 <= so_disp1;
		end
	end
end

endmodule
//------------------------------------------------------------------------------
/*------------------------------------------------------------------------------
-- \module pmod_ssd_out
--
-- \brief A two digit synchronous multiplexer to drive the Digilent PmodSSD with
-- two unique digit values. The 20 MHz input clock is divided to a multiplexing
-- of the PmodSSD at 100 Hz.
--
-- \description None
------------------------------------------------------------------------------*/
//Part 1: Module header:--------------------------------------------------------
module pmod_ssd_out(o_dispA, o_selA, i_clk_20mhz, i_rst_20mhz, i_disp0,
	i_disp1);

output wire [6:0] o_dispA;
output wire o_selA;
input wire i_clk_20mhz;
input wire i_rst_20mhz;
input wire [6:0] i_disp0;
input wire [6:0] i_disp1;

// Part 2: Declarations---------------------------------------------------------
wire s_clk_100hz;
wire s_rst_100hz;
reg [6:0] s_curr_disp;
reg s_curr_sel;

//Part 3: Statements------------------------------------------------------------

/* A clock divider instance is used to divided the clock by a factor of
   100000, which for a source clock of 10 MHz, outputs a resulting clock
   of 100 Hz.
   The create_generated_clock command must be added to the Xilinx XDC,
   for unit \ref u_clock_divider in every instance of \ref pmod_ssd_out . */
clock_divider #(.par_clk_divisor(200000)) u_clock_divider(
	.i_clk_mhz(i_clk_20mhz),
	.i_rst_mhz(i_rst_20mhz),
	.o_clk_div(s_clk_100hz),
	.o_rst_div(s_rst_100hz));

/* A process to multiplex the registered output of inputs \ref i_disp0
   and \ref i_disp1 to a single LED segment value of \ref o_dispA and
   digit select of \ref o_selA; */
always @(posedge s_clk_100hz)
begin: p_mux_disp_out
	if (s_clk_100hz) begin
		if (s_rst_100hz) begin
			s_curr_sel <= 1'b0;
			s_curr_disp <= 7'b0000000;
		end else begin
			if (s_curr_sel) begin
				s_curr_sel <= 1'b0;
				s_curr_disp <= i_disp0;
			end else begin
				s_curr_sel <= 1'b1;
				s_curr_disp <= i_disp1;
			end
		end
	end
end

assign o_dispA = s_curr_disp;
assign o_selA = s_curr_sel;

endmodule
//------------------------------------------------------------------------------
/*------------------------------------------------------------------------------
-- \module two_pmod_ssd_display
--
-- \brief A top-level display for one PmodSSD device. The top-level display
-- driver is configured to input two 4-bit hexadecimal values, and output them
-- with a PmodSSD driver to one PmodSSD via the 8-bit PMOD interface.
--
-- \description None
------------------------------------------------------------------------------*/
//Part 1: Module header:--------------------------------------------------------
module one_pmod_ssd_display(o_ssd_pmod0, i_clk_20mhz, i_rst_20mhz, i_value0,
	i_value1);

output wire [7:0] o_ssd_pmod0;
input wire i_clk_20mhz;
input wire i_rst_20mhz;
input wire [3:0] i_value0;
input wire [3:0] i_value1;

// Part 2: Declarations---------------------------------------------------------
wire [6:0] s_disp0;
wire [6:0] s_disp1;

//Part 3: Statements------------------------------------------------------------

/* An instance of \ref two_digit_ssd_out that converts two hexadecimal bytes
   into two discrete active-high 7-segment emitter values.
   This instance controls the emitters for a single two-digit Pmod SSD. */
two_digit_ssd_out #() u_two_digit_ssd_out (
	.i_clk_20mhz(i_clk_20mhz),
	.i_rst_20mhz(i_rst_20mhz),
	.i_value({i_value1, i_value0}),
	.o_disp0(s_disp0),
	.o_disp1(s_disp1));

/* An instance of \ref pmod_ssd_out that multiplexes two discrete 7-segment
   emitter values to a single emitter value with single bit multiplexer
   select line, as per the PmodSSD by Digilent Inc. This instance is connected
   to drive the single Pmod SSD. */
pmod_ssd_out #() u_pmod_ssd_out (
	.i_clk_20mhz(i_clk_20mhz),
	.i_rst_20mhz(i_rst_20mhz),
	.i_disp0(s_disp0),
	.i_disp1(s_disp1),
	.o_dispA(o_ssd_pmod0[6-:7]),
	.o_selA(o_ssd_pmod0[7]));

endmodule
//------------------------------------------------------------------------------
