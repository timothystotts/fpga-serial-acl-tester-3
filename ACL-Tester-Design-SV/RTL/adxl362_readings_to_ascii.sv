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
-- \file adxl362_readings_to_ascii.sv
--
-- \brief A combinatorial block to convert ADXL362 Readings to ASCII text
-- representations.
------------------------------------------------------------------------------*/
`begin_keywords "1800-2017"
//Combinatorial measurement registers to ASCII text conversion.-----------------
//Part 1: Module header:--------------------------------------------------------
module adxl362_readings_to_ascii(
	input logic [(8*8-1):0] i_3axis_temp,
	input logic i_reading_inactive,
	output logic [(16*8-1):0] o_dat_ascii_line1,
	output logic [(16*8-1):0] o_dat_ascii_line2,
	output logic [(16*8-1):0] o_txt_ascii_line1,
	output logic [(16*8-1):0] o_txt_ascii_line2);

//Part 2: Declarations----------------------------------------------------------
timeunit 1ns;
timeprecision 1ps;

/* A re-entrant function that converts a 4-bit part-select to an 8-bit ASCII
   hexadecimal character. */
function automatic [7:0] ascii_of_hdigit(input [3:0] bchex_val);
	begin
		if (bchex_val < 10) ascii_of_hdigit = 8'h30 + {4'h0, bchex_val};
		else ascii_of_hdigit = 8'h37 + {4'h0, bchex_val};
	end
endfunction

/* Connections for reparse of the eight PMOD ACL2 measurement reading bytes */
logic [7:0] s_hex_xaxis_msb;
logic [7:0] s_hex_xaxis_lsb;
logic [7:0] s_hex_yaxis_msb;
logic [7:0] s_hex_yaxis_lsb;
logic [7:0] s_hex_zaxis_msb;
logic [7:0] s_hex_zaxis_lsb;
logic [7:0] s_hex_temp_msb;
logic [7:0] s_hex_temp_lsb;

/* Connections for reparse of the eight PMOD ACL2 measurement reading bytes */
localparam signed [15:0] c_signed_zero = 0;
logic signed [15:0] s_txt_xaxis_s16;
logic signed [15:0] s_txt_yaxis_s16;
logic signed [15:0] s_txt_zaxis_s16;
logic signed [15:0] s_txt_temp_s16;
logic [15:0] s_txt_xaxis_u16;
logic [15:0] s_txt_yaxis_u16;
logic [15:0] s_txt_zaxis_u16;
logic [15:0] s_txt_temp_u16;

/* Connections for Hex to ASCII reparse of the sixteen digits of the eight
   PMOD ACL2 measurement reading bytes */
logic [7:0] s_char_xaxis_msb_3;
logic [7:0] s_char_xaxis_msb_2;
logic [7:0] s_char_xaxis_lsb_1;
logic [7:0] s_char_xaxis_lsb_0;
logic [7:0] s_char_yaxis_msb_3;
logic [7:0] s_char_yaxis_msb_2;
logic [7:0] s_char_yaxis_lsb_1;
logic [7:0] s_char_yaxis_lsb_0;
logic [7:0] s_char_zaxis_msb_3;
logic [7:0] s_char_zaxis_msb_2;
logic [7:0] s_char_zaxis_lsb_1;
logic [7:0] s_char_zaxis_lsb_0;
logic [7:0] s_char_temp_msb_3;
logic [7:0] s_char_temp_msb_2;
logic [7:0] s_char_temp_lsb_1;
logic [7:0] s_char_temp_lsb_0;

/* Signals for Decimal to ASCII reparse of the sixteen digits of the eight
   PMOD ACL2 measurement reading bytes */
logic [15:0] s_dat_xaxis_m0;
logic [15:0] s_dat_xaxis_f0;
logic [15:0] s_dat_xaxis_f1;
logic [15:0] s_dat_xaxis_f2;

logic [7:0] s_char_xaxis_sg;
logic [7:0] s_char_xaxis_m0;
logic [7:0] s_char_xaxis_f0;
logic [7:0] s_char_xaxis_f1;
logic [7:0] s_char_xaxis_f2;

logic [15:0] s_dat_yaxis_m0;
logic [15:0] s_dat_yaxis_f0;
logic [15:0] s_dat_yaxis_f1;
logic [15:0] s_dat_yaxis_f2;

logic [7:0] s_char_yaxis_sg;
logic [7:0] s_char_yaxis_m0;
logic [7:0] s_char_yaxis_f0;
logic [7:0] s_char_yaxis_f1;
logic [7:0] s_char_yaxis_f2;

logic [15:0] s_dat_zaxis_m0;
logic [15:0] s_dat_zaxis_f0;
logic [15:0] s_dat_zaxis_f1;
logic [15:0] s_dat_zaxis_f2;

logic [7:0] s_char_zaxis_sg;
logic [7:0] s_char_zaxis_m0;
logic [7:0] s_char_zaxis_f0;
logic [7:0] s_char_zaxis_f1;
logic [7:0] s_char_zaxis_f2;

logic [15:0] s_dat_temp_m3;
logic [15:0] s_dat_temp_m2;
logic [15:0] s_dat_temp_m1;
logic [15:0] s_dat_temp_m0;

logic [7:0] s_char_temp_m3;
logic [7:0] s_char_temp_m2;
logic [7:0] s_char_temp_m1;
logic [7:0] s_char_temp_m0;

//Part 3: Statements------------------------------------------------------------
/* Parse out the hexadecimal reading of mg force and temperature from the
   PMOD ACL2 data register readings. This partsing is done to display the
   measurement readings at a slower refresh rate on the PMOD CLS. */
assign s_hex_xaxis_lsb = i_3axis_temp[(8*8-1)-:8];
assign s_hex_xaxis_msb = i_3axis_temp[(7*8-1)-:8];
assign s_hex_yaxis_lsb = i_3axis_temp[(6*8-1)-:8];
assign s_hex_yaxis_msb = i_3axis_temp[(5*8-1)-:8];
assign s_hex_zaxis_lsb = i_3axis_temp[(4*8-1)-:8];
assign s_hex_zaxis_msb = i_3axis_temp[(3*8-1)-:8];
assign s_hex_temp_lsb = i_3axis_temp[(2*8-1)-:8];
assign s_hex_temp_msb = i_3axis_temp[(1*8-1)-:8];

assign s_txt_xaxis_s16 = {s_hex_xaxis_msb, s_hex_xaxis_lsb};
assign s_txt_yaxis_s16 = {s_hex_yaxis_msb, s_hex_yaxis_lsb};
assign s_txt_zaxis_s16 = {s_hex_zaxis_msb, s_hex_zaxis_lsb};
assign s_txt_temp_s16 = {s_hex_temp_msb, s_hex_temp_lsb};

assign s_txt_xaxis_u16 = (s_txt_xaxis_s16 < 0) ? (c_signed_zero - s_txt_xaxis_s16) : s_txt_xaxis_s16;
assign s_txt_yaxis_u16 = (s_txt_yaxis_s16 < 0) ? (c_signed_zero - s_txt_yaxis_s16) : s_txt_yaxis_s16;
assign s_txt_zaxis_u16 = (s_txt_zaxis_s16 < 0) ? (c_signed_zero - s_txt_zaxis_s16) : s_txt_zaxis_s16;
assign s_txt_temp_u16 = (s_txt_temp_s16 < 0) ? (c_signed_zero - s_txt_temp_s16) : s_txt_temp_s16;

/* ASCII parse-out of the X-Axis measurement reading. */
assign s_char_xaxis_msb_3 = ascii_of_hdigit(s_hex_xaxis_msb[7-:4]);
assign s_char_xaxis_msb_2 = ascii_of_hdigit(s_hex_xaxis_msb[3-:4]);
assign s_char_xaxis_lsb_1 = ascii_of_hdigit(s_hex_xaxis_lsb[7-:4]);
assign s_char_xaxis_lsb_0 = ascii_of_hdigit(s_hex_xaxis_lsb[3-:4]);

assign s_dat_xaxis_m0 = (s_txt_xaxis_u16 / 1000) % 10;
assign s_dat_xaxis_f0 = (s_txt_xaxis_u16 / 100) % 10;
assign s_dat_xaxis_f1 = (s_txt_xaxis_u16 / 10) % 10;
assign s_dat_xaxis_f2 = s_txt_xaxis_u16 % 10;

assign s_char_xaxis_sg = (s_txt_xaxis_s16[15] == 1'b1) ? 8'h2D : 8'h20;
assign s_char_xaxis_m0 = ascii_of_hdigit(s_dat_xaxis_m0[3-:4]);
assign s_char_xaxis_f0 = ascii_of_hdigit(s_dat_xaxis_f0[3-:4]);
assign s_char_xaxis_f1 = ascii_of_hdigit(s_dat_xaxis_f1[3-:4]);
assign s_char_xaxis_f2 = ascii_of_hdigit(s_dat_xaxis_f2[3-:4]);

/* ASCII parse-out of the Y-Axis measurement reading. */
assign s_char_yaxis_msb_3 = ascii_of_hdigit(s_hex_yaxis_msb[7-:4]);
assign s_char_yaxis_msb_2 = ascii_of_hdigit(s_hex_yaxis_msb[3-:4]);
assign s_char_yaxis_lsb_1 = ascii_of_hdigit(s_hex_yaxis_lsb[7-:4]);
assign s_char_yaxis_lsb_0 = ascii_of_hdigit(s_hex_yaxis_lsb[3-:4]);

assign s_dat_yaxis_m0 = (s_txt_yaxis_u16 / 1000) % 10;
assign s_dat_yaxis_f0 = (s_txt_yaxis_u16 / 100) % 10;
assign s_dat_yaxis_f1 = (s_txt_yaxis_u16 / 10) % 10;
assign s_dat_yaxis_f2 = s_txt_yaxis_u16 % 10;

assign s_char_yaxis_sg = (s_txt_yaxis_s16[15] == 1'b1) ? 8'h2D : 8'h20;
assign s_char_yaxis_m0 = ascii_of_hdigit(s_dat_yaxis_m0[3-:4]);
assign s_char_yaxis_f0 = ascii_of_hdigit(s_dat_yaxis_f0[3-:4]);
assign s_char_yaxis_f1 = ascii_of_hdigit(s_dat_yaxis_f1[3-:4]);
assign s_char_yaxis_f2 = ascii_of_hdigit(s_dat_yaxis_f2[3-:4]);

/* ASCII parse-out of the Z-Axis measurement reading. */
assign s_char_zaxis_msb_3 = ascii_of_hdigit(s_hex_zaxis_msb[7-:4]);
assign s_char_zaxis_msb_2 = ascii_of_hdigit(s_hex_zaxis_msb[3-:4]);
assign s_char_zaxis_lsb_1 = ascii_of_hdigit(s_hex_zaxis_lsb[7-:4]);
assign s_char_zaxis_lsb_0 = ascii_of_hdigit(s_hex_zaxis_lsb[3-:4]);

assign s_dat_zaxis_m0 = (s_txt_zaxis_u16 / 1000) % 10;
assign s_dat_zaxis_f0 = (s_txt_zaxis_u16 / 100) % 10;
assign s_dat_zaxis_f1 = (s_txt_zaxis_u16 / 10) % 10;
assign s_dat_zaxis_f2 = s_txt_zaxis_u16 % 10;

assign s_char_zaxis_sg = (s_txt_zaxis_s16[15] == 1'b1) ? 8'h2D : 8'h20;
assign s_char_zaxis_m0 = ascii_of_hdigit(s_dat_zaxis_m0[3-:4]);
assign s_char_zaxis_f0 = ascii_of_hdigit(s_dat_zaxis_f0[3-:4]);
assign s_char_zaxis_f1 = ascii_of_hdigit(s_dat_zaxis_f1[3-:4]);
assign s_char_zaxis_f2 = ascii_of_hdigit(s_dat_zaxis_f2[3-:4]);

/* ASCII parse-out of the Compensating Temperature measurement reading. */
assign s_char_temp_msb_3 = ascii_of_hdigit(s_hex_temp_msb[7-:4]);
assign s_char_temp_msb_2 = ascii_of_hdigit(s_hex_temp_msb[3-:4]);
assign s_char_temp_lsb_1 = ascii_of_hdigit(s_hex_temp_lsb[7-:4]);
assign s_char_temp_lsb_0 = ascii_of_hdigit(s_hex_temp_lsb[3-:4]);

assign s_dat_temp_m3 = (s_txt_temp_u16 / 1000) % 10;
assign s_dat_temp_m2 = (s_txt_temp_u16 / 100) % 10;
assign s_dat_temp_m1 = (s_txt_temp_u16 / 10) % 10;
assign s_dat_temp_m0 = s_txt_temp_u16 % 10;

assign s_char_temp_m3 = ascii_of_hdigit(s_dat_temp_m3[3-:4]);
assign s_char_temp_m2 = ascii_of_hdigit(s_dat_temp_m2[3-:4]);
assign s_char_temp_m1 = ascii_of_hdigit(s_dat_temp_m1[3-:4]);
assign s_char_temp_m0 = ascii_of_hdigit(s_dat_temp_m0[3-:4]);

/* Assemblly of ASCII Line 1 to display on the PMOD CLS. */
/* ASCII Line:  "X:____  Y:____  " or "X:0123  Y:ABCD  " */
assign o_dat_ascii_line1 = (i_reading_inactive)
								?
								{8'h58, 8'h3A,
								8'h5F, 8'h5F, 8'h5F, 8'h5F,
								8'h20, 8'h20, 8'h59, 8'h3A, 
								8'h5F, 8'h5F, 8'h5F, 8'h5F,
							    8'h20, 8'h20}
								:
								{8'h58, 8'h3A, s_char_xaxis_msb_3,
								s_char_xaxis_msb_2, s_char_xaxis_lsb_1,
								s_char_xaxis_lsb_0, 8'h20, 8'h20,
								8'h59, 8'h3A, s_char_yaxis_msb_3,
								s_char_yaxis_msb_2, s_char_yaxis_lsb_1,
								s_char_yaxis_lsb_0, 8'h20, 8'h20}
								;

/* ASCII line: "X______ Y______ " or "X-0.123 Y 0.345 " */
assign o_txt_ascii_line1 = (i_reading_inactive)
								?
								{8'h58, 8'h5F,
								8'h5F, 8'h5F, 8'h5F, 8'h5F,
								8'h5F, 8'h20, 8'h59, 8'h5F, 
								8'h5F, 8'h5F, 8'h5F, 8'h5F,
							    8'h5F, 8'h20}
								:
								{8'h58, s_char_xaxis_sg,
								s_char_xaxis_m0, 8'h2E, s_char_xaxis_f0,
								s_char_xaxis_f1, s_char_xaxis_f2, 8'h20,
								8'h59, s_char_yaxis_sg,
								s_char_yaxis_m0, 8'h2E, s_char_yaxis_f0,
								s_char_yaxis_f1, s_char_yaxis_f2, 8'h20}
								;

/* Assemblly of ASCII Line 2 to display on the PMOD CLS. */
/* ASCII Line:  "Z:____  T:____  " or "Z:0123  T:ABCD  " */
assign o_dat_ascii_line2 = (i_reading_inactive)
								?
								{8'h5A, 8'h3A,
								8'h5F, 8'h5F, 8'h5F, 8'h5F,
								8'h20, 8'h20, 8'h54, 8'h3A,
								8'h5F, 8'h5F, 8'h5F, 8'h5F,
								8'h20, 8'h20}
								:
								{8'h5A, 8'h3A, s_char_zaxis_msb_3,
								s_char_zaxis_msb_2, s_char_zaxis_lsb_1,
								s_char_zaxis_lsb_0, 8'h20, 8'h20,
								8'h54, 8'h3A, s_char_temp_msb_3,
								s_char_temp_msb_2, s_char_temp_lsb_1,
								s_char_temp_lsb_0, 8'h20, 8'h20}
								;

/* ASCII line: "Z______ T______ " or "Z 1.123 T5201   " */
assign o_txt_ascii_line2 = (i_reading_inactive)
								?
								{8'h5A, 8'h5F,
								8'h5F, 8'h5F, 8'h5F, 8'h5F,
								8'h5F, 8'h20, 8'h54, 8'h5F, 
								8'h5F, 8'h5F, 8'h5F, 8'h5F,
							    8'h20, 8'h20}
								:
								{8'h5A, s_char_zaxis_sg,
								s_char_zaxis_m0, 8'h2E, s_char_zaxis_f0,
								s_char_zaxis_f1, s_char_zaxis_f2, 8'h20,
								8'h54, s_char_temp_m3, s_char_temp_m2,
								s_char_temp_m1, s_char_temp_m0, 8'h20, 8'h20, 8'h20}
								;

endmodule : adxl362_readings_to_ascii
//------------------------------------------------------------------------------
`end_keywords
