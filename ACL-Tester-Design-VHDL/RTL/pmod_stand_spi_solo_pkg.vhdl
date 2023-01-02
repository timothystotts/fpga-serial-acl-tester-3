--------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2021-2022 Timothy Stotts
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
-- \file pmod_stand_spi_solo_pkg.vhdl
--
-- \brief A package of definitions used by the SPI drivers.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--------------------------------------------------------------------------------
package pmod_stand_spi_solo_pkg is

    -- Types for Pmod CLS custom driver
    subtype t_pmod_cls_cmd_len is natural range 0 to 15;
    subtype t_pmod_cls_dat_len is natural range 0 to 31;
    subtype t_pmod_cls_cmd_txlen is natural range 0 to 31;
    subtype t_pmod_cls_dat_txlen is natural range 0 to 63;
    subtype t_pmod_cls_ansi_line_7 is std_logic_vector((7 * 8 - 1) downto 0);
    subtype t_pmod_cls_ascii_line_16 is std_logic_vector((16 * 8 - 1) downto 0);

    -- LOG2 of the TX FIFO max count
    constant c_pmod_cls_tx_len_bits : natural := 11;
    -- LOG2 of max Wait Cycles count between end of TX and start of RX
    constant c_pmod_cls_wait_cyc_bits : natural := 2;
    -- LOG2 of the RX FIFO max count
    constant c_pmod_cls_rx_len_bits : natural := 11;

    subtype t_pmod_cls_data_byte is std_logic_vector(7 downto 0);
    subtype t_pmod_cls_tx_len is std_logic_vector((c_pmod_cls_tx_len_bits - 1) downto 0);
    subtype t_pmod_cls_wait_cyc is std_logic_vector((c_pmod_cls_wait_cyc_bits - 1) downto 0);
    subtype t_pmod_cls_rx_len is std_logic_vector((c_pmod_cls_rx_len_bits - 1) downto 0);

    -- Typedefs for Pmod ACL2 custom driver
    subtype t_pmod_acl2_reg_1 is std_logic_vector((1 * 8 - 1) downto 0);
    subtype t_pmod_acl2_reg_2 is std_logic_vector((2 * 8 - 1) downto 0);
    subtype t_pmod_acl2_reg_7 is std_logic_vector((7 * 8 - 1) downto 0);
    subtype t_pmod_acl2_reg_8 is std_logic_vector((8 * 8 - 1) downto 0);
    subtype t_pmod_acl2_reg_34 is std_logic_vector((34 * 8 - 1) downto 0);

    -- LOG2 of the TX FIFO max count
    constant c_pmod_acl2_tx_len_bits : natural := 11;
    -- LOG2 of max Wait Cycles count between end of TX and start of RX
    constant c_pmod_acl2_wait_cyc_bits : natural := 2;
    -- LOG2 of the RX FIFO max count
    constant c_pmod_acl2_rx_len_bits : natural := 11;

    subtype t_pmod_acl2_data_byte is std_logic_vector(7 downto 0);
    subtype t_pmod_acl2_tx_len is std_logic_vector((c_pmod_acl2_tx_len_bits - 1) downto 0);
    subtype t_pmod_acl2_wait_cyc is std_logic_vector((c_pmod_acl2_wait_cyc_bits - 1) downto 0);
    subtype t_pmod_acl2_rx_len is std_logic_vector((c_pmod_acl2_rx_len_bits - 1) downto 0);

    -- ASCII constant characters for ANSI ESC codes.
    -- ASCII constant characters for ESC codes.
    constant ASCII_CLS_ESC            : std_logic_vector(7 downto 0) := x"1B";
    constant ASCII_CLS_BRACKET        : std_logic_vector(7 downto 0) := x"5B";
    constant ASCII_CLS_CHAR_ZERO      : std_logic_vector(7 downto 0) := x"30";
    constant ASCII_CLS_CHAR_ONE       : std_logic_vector(7 downto 0) := x"31";
    constant ASCII_CLS_CHAR_SEMICOLON : std_logic_vector(7 downto 0) := x"3B";
    constant ASCII_CLS_DISP_CLR_CMD   : std_logic_vector(7 downto 0) := x"6a";
    constant ASCII_CLS_CURSOR_POS_CMD : std_logic_vector(7 downto 0) := x"48";

end package pmod_stand_spi_solo_pkg;
--------------------------------------------------------------------------------
