--------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020,2022 Timothy Stotts
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
--------------------------------------------------------------------------------
-- \file adxl362_readings_to_ascii.vhdl
--
-- \brief A combinatorial block to convert ADXL362 Readings to ASCII text
-- representations.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.lcd_text_functions_pkg.ascii_of_hdigit;
--------------------------------------------------------------------------------
entity adxl362_readings_to_ascii is
	port(
		i_3axis_temp       : in std_logic_vector((8*8-1) downto 0);
		i_reading_inactive : in std_logic;
		o_dat_ascii_line1  : out std_logic_vector((16*8-1) downto 0);
		o_dat_ascii_line2  : out std_logic_vector((16*8-1) downto 0);
		o_txt_ascii_line1  : out std_logic_vector((16*8-1) downto 0);
		o_txt_ascii_line2  : out std_logic_vector((16*8-1) downto 0)
	);
end entity adxl362_readings_to_ascii;
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
architecture rtl of adxl362_readings_to_ascii is
	-- Signals for reparse of the eight PMOD ACL2 measurement reading bytes
	signal s_hex_xaxis_msb : std_logic_vector(7 downto 0);
	signal s_hex_xaxis_lsb : std_logic_vector(7 downto 0);
	signal s_hex_xaxis_16  : std_logic_vector(15 downto 0);
	signal s_hex_yaxis_msb : std_logic_vector(7 downto 0);
	signal s_hex_yaxis_lsb : std_logic_vector(7 downto 0);
	signal s_hex_yaxis_16  : std_logic_vector(15 downto 0);
	signal s_hex_zaxis_msb : std_logic_vector(7 downto 0);
	signal s_hex_zaxis_lsb : std_logic_vector(7 downto 0);
	signal s_hex_zaxis_16  : std_logic_vector(15 downto 0);
	signal s_hex_temp_msb  : std_logic_vector(7 downto 0);
	signal s_hex_temp_lsb  : std_logic_vector(7 downto 0);
	signal s_hex_temp_16   : std_logic_vector(15 downto 0);

	-- Signals for reparse of the eight PMOD ACL2 measurement reading bytes
	constant c_signed_zero : signed(15 downto 0) := signed'(x"0000");
	signal s_txt_xaxis_s16 : signed(15 downto 0);
	signal s_txt_yaxis_s16 : signed(15 downto 0);
	signal s_txt_zaxis_s16 : signed(15 downto 0);
	signal s_txt_temp_s16  : signed(15 downto 0);
	signal s_txt_xaxis_u16 : unsigned(15 downto 0);
	signal s_txt_yaxis_u16 : unsigned(15 downto 0);
	signal s_txt_zaxis_u16 : unsigned(15 downto 0);
	signal s_txt_temp_u16  : unsigned(15 downto 0);

	-- Signals for Hex to ASCII reparse of the sixteen digits of the eight
	-- PMOD ACL2 measurement reading bytes
	signal s_char_xaxis_msb_3 : std_logic_vector(7 downto 0);
	signal s_char_xaxis_msb_2 : std_logic_vector(7 downto 0);
	signal s_char_xaxis_lsb_1 : std_logic_vector(7 downto 0);
	signal s_char_xaxis_lsb_0 : std_logic_vector(7 downto 0);
	signal s_char_yaxis_msb_3 : std_logic_vector(7 downto 0);
	signal s_char_yaxis_msb_2 : std_logic_vector(7 downto 0);
	signal s_char_yaxis_lsb_1 : std_logic_vector(7 downto 0);
	signal s_char_yaxis_lsb_0 : std_logic_vector(7 downto 0);
	signal s_char_zaxis_msb_3 : std_logic_vector(7 downto 0);
	signal s_char_zaxis_msb_2 : std_logic_vector(7 downto 0);
	signal s_char_zaxis_lsb_1 : std_logic_vector(7 downto 0);
	signal s_char_zaxis_lsb_0 : std_logic_vector(7 downto 0);
	signal s_char_temp_msb_3  : std_logic_vector(7 downto 0);
	signal s_char_temp_msb_2  : std_logic_vector(7 downto 0);
	signal s_char_temp_lsb_1  : std_logic_vector(7 downto 0);
	signal s_char_temp_lsb_0  : std_logic_vector(7 downto 0);

	-- Signals for Decimal to ASCII reparse of the sixteen digits of the eight
	-- PMOD ACL2 measurement reading bytes
	signal s_dat_xaxis_m0 : std_logic_vector(15 downto 0);
	signal s_dat_xaxis_f0 : std_logic_vector(15 downto 0);
	signal s_dat_xaxis_f1 : std_logic_vector(15 downto 0);
	signal s_dat_xaxis_f2 : std_logic_vector(15 downto 0);

	signal s_char_xaxis_sg : std_logic_vector(7 downto 0);
	signal s_char_xaxis_m0 : std_logic_vector(7 downto 0);
	signal s_char_xaxis_f0 : std_logic_vector(7 downto 0);
	signal s_char_xaxis_f1 : std_logic_vector(7 downto 0);
	signal s_char_xaxis_f2 : std_logic_vector(7 downto 0);

	signal s_dat_yaxis_m0 : std_logic_vector(15 downto 0);
	signal s_dat_yaxis_f0 : std_logic_vector(15 downto 0);
	signal s_dat_yaxis_f1 : std_logic_vector(15 downto 0);
	signal s_dat_yaxis_f2 : std_logic_vector(15 downto 0);

	signal s_char_yaxis_sg : std_logic_vector(7 downto 0);
	signal s_char_yaxis_m0 : std_logic_vector(7 downto 0);
	signal s_char_yaxis_f0 : std_logic_vector(7 downto 0);
	signal s_char_yaxis_f1 : std_logic_vector(7 downto 0);
	signal s_char_yaxis_f2 : std_logic_vector(7 downto 0);

	signal s_dat_zaxis_m0 : std_logic_vector(15 downto 0);
	signal s_dat_zaxis_f0 : std_logic_vector(15 downto 0);
	signal s_dat_zaxis_f1 : std_logic_vector(15 downto 0);
	signal s_dat_zaxis_f2 : std_logic_vector(15 downto 0);

	signal s_char_zaxis_sg : std_logic_vector(7 downto 0);
	signal s_char_zaxis_m0 : std_logic_vector(7 downto 0);
	signal s_char_zaxis_f0 : std_logic_vector(7 downto 0);
	signal s_char_zaxis_f1 : std_logic_vector(7 downto 0);
	signal s_char_zaxis_f2 : std_logic_vector(7 downto 0);

	signal s_dat_temp_m3 : std_logic_vector(15 downto 0);
	signal s_dat_temp_m2 : std_logic_vector(15 downto 0);
	signal s_dat_temp_m1 : std_logic_vector(15 downto 0);
	signal s_dat_temp_m0 : std_logic_vector(15 downto 0);

	signal s_char_temp_m3 : std_logic_vector(7 downto 0);
	signal s_char_temp_m2 : std_logic_vector(7 downto 0);
	signal s_char_temp_m1 : std_logic_vector(7 downto 0);
	signal s_char_temp_m0 : std_logic_vector(7 downto 0);
begin
	-- Parse out the hexadecimal reading of mg force and temperature from the
	-- PMOD ACL2 data register readings. This parsing is done to display the
	-- measurement readings at a slower refresh rate on the PMOD CLS.
	s_hex_xaxis_lsb <= i_3axis_temp((8*8-1) downto (7*8));
	s_hex_xaxis_msb <= i_3axis_temp((7*8-1) downto (6*8));
	s_hex_yaxis_lsb <= i_3axis_temp((6*8-1) downto (5*8));
	s_hex_yaxis_msb <= i_3axis_temp((5*8-1) downto (4*8));
	s_hex_zaxis_lsb <= i_3axis_temp((4*8-1) downto (3*8));
	s_hex_zaxis_msb <= i_3axis_temp((3*8-1) downto (2*8));
	s_hex_temp_lsb  <= i_3axis_temp((2*8-1) downto (1*8));
	s_hex_temp_msb  <= i_3axis_temp((1*8-1) downto 0);

	s_hex_xaxis_16  <= std_logic_vector(s_hex_xaxis_msb) & std_logic_vector(s_hex_xaxis_lsb);
	s_txt_xaxis_s16 <= signed(s_hex_xaxis_16);
	s_hex_yaxis_16  <= s_hex_yaxis_msb & s_hex_yaxis_lsb;
	s_txt_yaxis_s16 <= signed(s_hex_yaxis_16);
	s_hex_zaxis_16  <= s_hex_zaxis_msb & s_hex_zaxis_lsb;
	s_txt_zaxis_s16 <= signed(s_hex_zaxis_16);
	s_hex_temp_16   <= s_hex_temp_msb & s_hex_temp_lsb;
	s_txt_temp_s16  <= signed(s_hex_temp_16);

	s_txt_xaxis_u16 <= unsigned(c_signed_zero - s_txt_xaxis_s16) when (s_txt_xaxis_s16(15) = '1') else unsigned(s_txt_xaxis_s16);
	s_txt_yaxis_u16 <= unsigned(c_signed_zero - s_txt_yaxis_s16) when (s_txt_yaxis_s16(15) = '1') else unsigned(s_txt_yaxis_s16);
	s_txt_zaxis_u16 <= unsigned(c_signed_zero - s_txt_zaxis_s16) when (s_txt_zaxis_s16(15) = '1') else unsigned(s_txt_zaxis_s16);
	s_txt_temp_u16  <= unsigned(c_signed_zero - s_txt_temp_s16)  when (s_txt_temp_s16(15) = '1') else unsigned(s_txt_temp_s16);

	-- ASCII parse-out of the X-Axis measurement reading.
	s_char_xaxis_msb_3 <= ascii_of_hdigit(s_hex_xaxis_msb(7 downto 4));
	s_char_xaxis_msb_2 <= ascii_of_hdigit(s_hex_xaxis_msb(3 downto 0));
	s_char_xaxis_lsb_1 <= ascii_of_hdigit(s_hex_xaxis_lsb(7 downto 4));
	s_char_xaxis_lsb_0 <= ascii_of_hdigit(s_hex_xaxis_lsb(3 downto 0));

	s_dat_xaxis_m0 <= std_logic_vector((s_txt_xaxis_u16 / 1000) mod 10);
	s_dat_xaxis_f0 <= std_logic_vector((s_txt_xaxis_u16 / 100) mod 10);
	s_dat_xaxis_f1 <= std_logic_vector((s_txt_xaxis_u16 / 10) mod 10);
	s_dat_xaxis_f2 <= std_logic_vector(s_txt_xaxis_u16 mod 10);

	s_char_xaxis_sg <= x"2D" when (s_txt_xaxis_s16(15) = '1') else x"20";
	s_char_xaxis_m0 <= ascii_of_hdigit(s_dat_xaxis_m0(3 downto 0));
	s_char_xaxis_f0 <= ascii_of_hdigit(s_dat_xaxis_f0(3 downto 0));
	s_char_xaxis_f1 <= ascii_of_hdigit(s_dat_xaxis_f1(3 downto 0));
	s_char_xaxis_f2 <= ascii_of_hdigit(s_dat_xaxis_f2(3 downto 0));

	-- ASCII parse-out of the Y-Axis measurement reading.
	s_char_yaxis_msb_3 <= ascii_of_hdigit(s_hex_yaxis_msb(7 downto 4));
	s_char_yaxis_msb_2 <= ascii_of_hdigit(s_hex_yaxis_msb(3 downto 0));
	s_char_yaxis_lsb_1 <= ascii_of_hdigit(s_hex_yaxis_lsb(7 downto 4));
	s_char_yaxis_lsb_0 <= ascii_of_hdigit(s_hex_yaxis_lsb(3 downto 0));

	s_dat_yaxis_m0 <= std_logic_vector((s_txt_yaxis_u16 / 1000) mod 10);
	s_dat_yaxis_f0 <= std_logic_vector((s_txt_yaxis_u16 / 100) mod 10);
	s_dat_yaxis_f1 <= std_logic_vector((s_txt_yaxis_u16 / 10) mod 10);
	s_dat_yaxis_f2 <= std_logic_vector(s_txt_yaxis_u16 mod 10);

	s_char_yaxis_sg <= x"2D" when (s_txt_yaxis_s16(15) = '1') else x"20";
	s_char_yaxis_m0 <= ascii_of_hdigit(s_dat_yaxis_m0(3 downto 0));
	s_char_yaxis_f0 <= ascii_of_hdigit(s_dat_yaxis_f0(3 downto 0));
	s_char_yaxis_f1 <= ascii_of_hdigit(s_dat_yaxis_f1(3 downto 0));
	s_char_yaxis_f2 <= ascii_of_hdigit(s_dat_yaxis_f2(3 downto 0));

	-- ASCII parse-out of the Z-Axis measurement reading.
	s_char_zaxis_msb_3 <= ascii_of_hdigit(s_hex_zaxis_msb(7 downto 4));
	s_char_zaxis_msb_2 <= ascii_of_hdigit(s_hex_zaxis_msb(3 downto 0));
	s_char_zaxis_lsb_1 <= ascii_of_hdigit(s_hex_zaxis_lsb(7 downto 4));
	s_char_zaxis_lsb_0 <= ascii_of_hdigit(s_hex_zaxis_lsb(3 downto 0));

	s_dat_zaxis_m0 <= std_logic_vector((s_txt_zaxis_u16 / 1000) mod 10);
	s_dat_zaxis_f0 <= std_logic_vector((s_txt_zaxis_u16 / 100) mod 10);
	s_dat_zaxis_f1 <= std_logic_vector((s_txt_zaxis_u16 / 10) mod 10);
	s_dat_zaxis_f2 <= std_logic_vector(s_txt_zaxis_u16 mod 10);

	s_char_zaxis_sg <= x"2D" when (s_txt_zaxis_s16(15) = '1') else x"20";
	s_char_zaxis_m0 <= ascii_of_hdigit(s_dat_zaxis_m0(3 downto 0));
	s_char_zaxis_f0 <= ascii_of_hdigit(s_dat_zaxis_f0(3 downto 0));
	s_char_zaxis_f1 <= ascii_of_hdigit(s_dat_zaxis_f1(3 downto 0));
	s_char_zaxis_f2 <= ascii_of_hdigit(s_dat_zaxis_f2(3 downto 0));

	-- ASCII parse-out of the Compensating Temperature measurement reading.
	s_char_temp_msb_3 <= ascii_of_hdigit(s_hex_temp_msb(7 downto 4));
	s_char_temp_msb_2 <= ascii_of_hdigit(s_hex_temp_msb(3 downto 0));
	s_char_temp_lsb_1 <= ascii_of_hdigit(s_hex_temp_lsb(7 downto 4));
	s_char_temp_lsb_0 <= ascii_of_hdigit(s_hex_temp_lsb(3 downto 0));

	s_dat_temp_m3 <= std_logic_vector((s_txt_temp_u16 / 1000) mod 10);
	s_dat_temp_m2 <= std_logic_vector((s_txt_temp_u16 / 100) mod 10);
	s_dat_temp_m1 <= std_logic_vector((s_txt_temp_u16 / 10) mod 10);
	s_dat_temp_m0 <= std_logic_vector(s_txt_temp_u16 mod 10);

	s_char_temp_m3 <= ascii_of_hdigit(s_dat_temp_m3(3 downto 0));
	s_char_temp_m2 <= ascii_of_hdigit(s_dat_temp_m2(3 downto 0));
	s_char_temp_m1 <= ascii_of_hdigit(s_dat_temp_m1(3 downto 0));
	s_char_temp_m0 <= ascii_of_hdigit(s_dat_temp_m0(3 downto 0));

	-- Assemblly of ASCII Line 1 to display on the PMOD CLS and UART TX.
	-- ASCII Line:  "X:____  Y:____  " or "X:0123  Y:ABCD  "
	o_dat_ascii_line1 <= (x"58" & x"3A" &
			x"5F" & x"5F" & x"5F" & x"5F" &
			x"20" & x"20" & x"59" & x"3A" &
			x"5F" & x"5F" & x"5F" & x"5F" &
			x"20" & x"20")
	when (i_reading_inactive = '1') else
		(x"58" & x"3A" & s_char_xaxis_msb_3 &
			s_char_xaxis_msb_2 & s_char_xaxis_lsb_1 &
			s_char_xaxis_lsb_0 & x"20" & x"20" &
			x"59" & x"3A" & s_char_yaxis_msb_3 &
			s_char_yaxis_msb_2 & s_char_yaxis_lsb_1 &
			s_char_yaxis_lsb_0 & x"20" & x"20");

	-- ASCII line: "X______ Y______ " or "X-0.123 Y 0.345 "
	o_txt_ascii_line1 <= (x"58" & x"5F" &
			x"5F" & x"5F" & x"5F" & x"5F" &
			x"5F" & x"20" & x"59" & x"5F" &
			x"5F" & x"5F" & x"5F" & x"5F" &
			x"5F" & x"20")
	when (i_reading_inactive = '1') else
		(x"58" & s_char_xaxis_sg &
			s_char_xaxis_m0 & x"2E" & s_char_xaxis_f0 &
			s_char_xaxis_f1 & s_char_xaxis_f2 & x"20" &
			x"59" & s_char_yaxis_sg &
			s_char_yaxis_m0 & x"2E" & s_char_yaxis_f0 &
			s_char_yaxis_f1 & s_char_yaxis_f2 & x"20");

	-- Assemblly of ASCII Line 2 to display on the PMOD CLS.
	-- ASCII Line:  "Z:____  T:____  " or "Z:0123  T:ABCD  "
	o_dat_ascii_line2 <= (x"5A" & x"3A" &
			x"5F" & x"5F" & x"5F" & x"5F" &
			x"20" & x"20" & x"54" & x"3A" &
			x"5F" & x"5F" & x"5F" & x"5F" &
			x"20" & x"20")
	when (i_reading_inactive = '1') else
		(x"5A" & x"3A" & s_char_zaxis_msb_3 &
			s_char_zaxis_msb_2 & s_char_zaxis_lsb_1 &
			s_char_zaxis_lsb_0 & x"20" & x"20" &
			x"54" & x"3A" & s_char_temp_msb_3 &
			s_char_temp_msb_2 & s_char_temp_lsb_1 &
			s_char_temp_lsb_0 & x"20" & x"20");

	-- ASCII line: "Z______ T______ " or "Z 1.123 T5201   "
	o_txt_ascii_line2 <= (x"5A" & x"5F" &
			x"5F" & x"5F" & x"5F" & x"5F" &
			x"5F" & x"20" & x"54" & x"5F" &
			x"5F" & x"5F" & x"5F" & x"5F" &
			x"20" & x"20")
	when (i_reading_inactive = '1') else
		(x"5A" & s_char_zaxis_sg &
			s_char_zaxis_m0 & x"2E" & s_char_zaxis_f0 &
			s_char_zaxis_f1 & s_char_zaxis_f2 & x"20" &
			x"54" & s_char_temp_m3 & s_char_temp_m2 &
			s_char_temp_m1 & s_char_temp_m0 & x"20" & x"20" & x"20");

end architecture rtl;
--------------------------------------------------------------------------------
