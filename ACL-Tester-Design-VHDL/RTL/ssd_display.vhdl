---------------------------------------------------------------------------------
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
-- \file ssd_display.vhdl
--
-- \brief A Seven Segment Display driver for a single Pmod SSD. The input is a
-- 8-bit hexademical value which is displayed as hexadecimal on the Pmod SSD.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--------------------------------------------------------------------------------
entity two_digit_ssd_out is
    port(
        i_clk_20mhz : in  std_Logic;
        i_rst_20mhz : in  std_logic;
        i_value     : in  std_logic_vector(7 downto 0);
        o_disp0     : out std_logic_vector(6 downto 0);
        o_disp1     : out std_logic_vector(6 downto 0)
    );
end entity two_digit_ssd_out;
--------------------------------------------------------------------------------
architecture rtl of two_digit_ssd_out is
    function unsigned_to_ssd(val : unsigned(3 downto 0))
        return std_logic_vector is
        variable v_ret : std_logic_vector(6 downto 0);
    begin
        case val is
             when x"0"   => v_ret   := "0111111";
             when x"1"   => v_ret   := "0000110";
             when x"2"   => v_ret   := "1011011";
             when x"3"   => v_ret   := "1001111";
             when x"4"   => v_ret   := "1100110";
             when x"5"   => v_ret   := "1101101";
             when x"6"   => v_ret   := "1111101";
             when x"7"   => v_ret   := "0000111";
             when x"8"   => v_ret   := "1111111";
             when x"9"   => v_ret   := "1100111";
             when x"A"   => v_ret   := "1110111";
             when x"B"   => v_ret   := "1111100";
             when x"C"   => v_ret   := "0111001";
             when x"D"   => v_ret   := "1011110";
             when x"E"   => v_ret   := "1111001";
             when x"F"   => v_ret   := "1110001";
             when others => v_ret := "0000000";
        end case;

        return v_ret;
    end function unsigned_to_ssd;

    -- Converted input value
    signal si_value      : unsigned(7 downto 0);

    -- The right (LSByte) hexadecimal value.
    signal s_value_part0 : unsigned(3 downto 0);

    -- The left (MSByte) hexadecimal value.
    signal s_value_part1 : unsigned(3 downto 0);

    -- The right segment display value.
    signal so_disp0      : std_logic_vector(6 downto 0);

    -- The left segment display value.
    signal so_disp1      : std_logic_vector(6 downto 0);
begin
    -- input the value as an unsigned value ranging 0 to 255
    si_value <= unsigned(i_value);

    -- Convert the value input to lower and upper base ten digit
    s_value_part0 <= si_value(3 downto 0);
    s_value_part1 <= si_value(7 downto 4);

    -- Convert the lower and uppper digit to SSD segments
    so_disp0 <= unsigned_to_ssd(s_value_part0);
    so_disp1 <= unsigned_to_ssd(s_value_part1);

    -- Register the combinatorial pre-output
    p_reg_out : process(i_clk_20mhz)
    begin
        if rising_edge(i_clk_20mhz) then
            if (i_rst_20mhz = '1') then
                o_disp0 <= "0000000";
                o_disp1 <= "0000000";
            else
                o_disp0 <= so_disp0;
                o_disp1 <= so_disp1;
            end if;
        end if;
    end process p_reg_out;
end architecture rtl;
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- \module pmod_ssd_out
--
-- \brief A two digit synchronous multiplexer to drive the Digilent PmodSSD with
-- two unique digit values. The 20 MHz input clock is divided to a multiplexing
-- of the PmodSSD at 100 Hz.
--
-- \description None
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--------------------------------------------------------------------------------
entity pmod_ssd_out is -- DISPD
    port(
        i_clk_20mhz : in  std_logic;
        i_rst_20mhz : in  std_logic;
        i_disp0     : in  std_logic_vector(6 downto 0);
        i_disp1     : in  std_logic_vector(6 downto 0);
        o_dispA     : out std_logic_vector(6 downto 0);
        o_selA      : out std_logic
    );
end entity pmod_ssd_out;
--------------------------------------------------------------------------------
architecture rtl of pmod_ssd_out is
    signal s_clk_100hz : std_logic;
    signal s_rst_100hz : std_logic;
    signal s_curr_disp : std_logic_vector(6 downto 0);
    signal s_curr_sel  : std_logic;
begin
    -- A clock divider instance is used to divided the clock by a factor of
    -- 200000, which for a source clock of 20 MHz, outputs a resulting clock
    -- of 100 Hz.
    -- The create_generated_clock command must be added to the Xilinx XDC,
    -- for unit \ref u_clock_divider in every instance of \ref pmod_ssd_out .
    u_clock_divider : entity work.clock_divider
        generic map(
            par_clk_divisor => 200000
        )
        port map(
            i_clk_mhz => i_clk_20mhz,
            i_rst_mhz => i_rst_20mhz,
            o_clk_div => s_clk_100hz,
            o_rst_div => s_rst_100hz
        );

    -- A process to multiplex the registered output of inputs \ref i_disp0
    -- and \ref i_disp1 to a single LED segment value of \ref o_dispA and
    -- digit select of \ref o_selA;
    p_mux_disp_out : process(s_clk_100hz)
    begin
        if rising_edge(s_clk_100hz) then
            if (s_rst_100hz = '1') then
                s_curr_sel  <= '0';
                s_curr_disp <= (others => '0');
            else
                if (s_curr_sel = '1') then
                    s_curr_sel  <= '0';
                    s_curr_disp <= i_disp0;
                else
                    s_curr_sel  <= '1';
                    s_curr_disp <= i_disp1;
                end if;
            end if;
        end if;
    end process p_mux_disp_out;

    o_dispA <= s_curr_disp;
    o_selA  <= s_curr_sel;
end architecture rtl;
--------------------------------------------------------------------------------
-- \module one_pmod_ssd_display
--
-- \brief A top-level display for one PmodSSD device. The top-level display
-- driver is configured to input two 4-bit hexadecimal values, and output them
-- with a PmodSSD driver to one PmodSSD via the 8-bit PMOD interface.
--
-- \description None
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--------------------------------------------------------------------------------
entity one_pmod_ssd_display is
    port(
        i_clk_20mhz : in  std_logic;
        i_rst_20mhz : in  std_logic;
        i_value0    : in  std_logic_vector(3 downto 0);
        i_value1    : in  std_logic_vector(3 downto 0);
        o_ssd_pmod0 : out std_logic_vector(7 downto 0)
    );
end entity one_pmod_ssd_display;
--------------------------------------------------------------------------------
architecture rtl of one_pmod_ssd_display is
    signal s_disp0 : std_logic_vector(6 downto 0);
    signal s_disp1 : std_logic_vector(6 downto 0);
begin
    -- An instance of \ref two_digit_ssd_out that converts two hexadecimal bytes
    -- into two discrete active-high 7-segment emitter values.
    -- This instance controls the emitters for a single two-digit Pmod SSD.
    u_two_digit_ssd_out : entity work.two_digit_ssd_out
        port map (
            i_clk_20mhz         => i_clk_20mhz,
            i_rst_20mhz         => i_rst_20mhz,
            i_value(7 downto 4) => i_value1,
            i_value(3 downto 0) => i_value0,
            o_disp0             => s_disp0,
            o_disp1             => s_disp1
        );

    -- An instance of \ref pmod_ssd_out that multiplexes two discrete 7-segment
    -- emitter values to a single emitter value with single bit multiplexer
    -- select line, as per the PmodSSD by Digilent Inc.
    -- This instance is connected to drive the single Pmod SSD.
    u_pmod_ssd_out : entity work.pmod_ssd_out
        port map (
            i_clk_20mhz => i_clk_20mhz,
            i_rst_20mhz => i_rst_20mhz,
            i_disp0     => s_disp0,
            i_disp1     => s_disp1,
            o_dispA     => o_ssd_pmod0(6 downto 0),
            o_selA      => o_ssd_pmod0(7)
        );
end architecture rtl;
--------------------------------------------------------------------------------
