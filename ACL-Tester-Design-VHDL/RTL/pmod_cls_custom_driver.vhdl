--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------
-- \file pmod_cls_custom_driver.vhdl
--
-- \brief A wrapper for the single Chip Select, Standard SPI modules
--        \ref pmod_cls_stand_spi_solo and \ref pmod_generic_spi_solo ,
--        implementing a custom single-mode operation of the PMOD CLS by
--        Digilent Inc.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pmod_stand_spi_solo_pkg.all;
--------------------------------------------------------------------------------
entity pmod_cls_custom_driver is
    generic(
        -- Disable or enable fast FSM delays for simulation instead of impelementation.
        parm_fast_simulation : integer := 0;
        -- Actual frequency in Hz of \ref i_clk_20mhz
        parm_FCLK : natural := 20_000_000;
        -- Clock enable frequency in Hz of \ref i_ce_2_5mhz
        parm_FCLK_ce : natural := 2_500_000;
        -- Ratio of i_clk_20mhz to SPI sck bus output.
        parm_ext_spi_clk_ratio : natural := 32
    );
    port(
        -- Clock and reset, with clock at 32 times the frequency of the SPI bus,
        -- with a clock enable that is 4 times the frequency of the SPI bus.
        i_clk_20mhz : in std_logic;
        i_rst_20mhz : in std_logic;
        i_ce_2_5mhz : in std_logic;
        -- Outputs and inputs from the single SPI peripheral
        eo_sck_t  : out std_logic;
        eo_sck_o  : out std_logic;
        eo_csn_t  : out std_logic;
        eo_csn_o  : out std_logic;
        eo_copi_t : out std_logic;
        eo_copi_o : out std_logic;
        ei_cipo   : in  std_logic;
        -- Command ready indication, three possible commands to the driver, and two
        -- lines of text input to display on the LCD.
        o_command_ready        : out std_logic;
        i_cmd_wr_clear_display : in  std_logic;
        i_cmd_wr_text_line1    : in  std_logic;
        i_cmd_wr_text_line2    : in  std_logic;
        i_dat_ascii_line1      : in  t_pmod_cls_ascii_line_16;
        i_dat_ascii_line2      : in  t_pmod_cls_ascii_line_16
    );
end entity pmod_cls_custom_driver;
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
architecture rtl of pmod_cls_custom_driver is
    -- CLS SPI driver wiring to the Generic SPI driver.
    signal s_cls_go_stand   : std_logic;
    signal s_cls_spi_idle   : std_logic;
    signal s_cls_tx_len     : t_pmod_cls_tx_len;
    signal s_cls_wait_cyc   : t_pmod_cls_wait_cyc;
    signal s_cls_rx_len     : t_pmod_cls_rx_len;
    signal s_cls_tx_data    : t_pmod_cls_data_byte;
    signal s_cls_tx_enqueue : std_logic;
    signal s_cls_tx_ready   : std_logic;
    signal s_cls_rx_data    : t_pmod_cls_data_byte;
    signal s_cls_rx_dequeue : std_logic;
    signal s_cls_rx_valid   : std_logic;
    signal s_cls_rx_avail   : std_logic;

    -- CLS SPI outputs, FSM signals to register the SPI bus outputs for
    -- optimal timing closure and glitch minimization.
    signal sio_cls_sck_fsm_o  : std_logic;
    signal sio_cls_sck_fsm_t  : std_logic;
    signal sio_cls_csn_fsm_o  : std_logic;
    signal sio_cls_csn_fsm_t  : std_logic;
    signal sio_cls_copi_fsm_o : std_logic;
    signal sio_cls_copi_fsm_t : std_logic;

    -- CLS SPI input synchronizer signals, where the synchronizer is used to
    -- mitigate metastability.
    signal sio_cls_cipo_meta_i : std_logic;
    signal sio_cls_cipo_sync_i : std_logic;
begin

    -- Register the SPI output an extra 4x-SPI-clock clock cycle for better
    -- timing closure and glitch mitigation.
    p_reg_spi_fsm_out : process(i_clk_20mhz)
    begin
        if rising_edge(i_clk_20mhz) then
            if (i_ce_2_5mhz = '1') then
                eo_sck_o <= sio_cls_sck_fsm_o;
                eo_sck_t <= sio_cls_sck_fsm_t;

                eo_csn_o <= sio_cls_csn_fsm_o;
                eo_csn_t <= sio_cls_csn_fsm_t;

                eo_copi_o <= sio_cls_copi_fsm_o;
                eo_copi_t <= sio_cls_copi_fsm_t;
            end if;
        end if;
    end process p_reg_spi_fsm_out;

    -- Double-register the SPI input at 4x-SPI-clock cycle to prevent metastability.
    p_sync_spi_in : process(i_clk_20mhz)
    begin
        if rising_edge(i_clk_20mhz) then
            if (i_ce_2_5mhz = '1') then
                sio_cls_cipo_sync_i <= sio_cls_cipo_meta_i;
                sio_cls_cipo_meta_i <= ei_cipo;
            end if;
        end if;
    end process p_sync_spi_in;

    -- Single mode driver to operate the PMOD CLS via a stand-alone SPI driver.
    u_pmod_cls_stand_spi_solo : entity work.pmod_cls_stand_spi_solo(moore_fsm_recursive)
        generic map (
            parm_fast_simulation => parm_fast_simulation,
            parm_FCLK            => parm_FCLK,
            parm_FCLK_ce         => parm_FCLK_ce
        )
        port map (
            i_ext_spi_clk_x        => i_clk_20mhz,
            i_srst                 => i_rst_20mhz,
            i_spi_ce_4x            => i_ce_2_5mhz,
            o_go_stand             => s_cls_go_stand,
            i_spi_idle             => s_cls_spi_idle,
            o_tx_len               => s_cls_tx_len,
            o_wait_cyc             => s_cls_wait_cyc,
            o_rx_len               => s_cls_rx_len,
            o_tx_data              => s_cls_tx_data,
            o_tx_enqueue           => s_cls_tx_enqueue,
            i_tx_ready             => s_cls_tx_ready,
            i_rx_data              => s_cls_rx_data,
            o_rx_dequeue           => s_cls_rx_dequeue,
            i_rx_valid             => s_cls_rx_valid,
            i_rx_avail             => s_cls_rx_avail,
            o_command_ready        => o_command_ready,
            i_cmd_wr_clear_display => i_cmd_wr_clear_display,
            i_cmd_wr_text_line1    => i_cmd_wr_text_line1,
            i_cmd_wr_text_line2    => i_cmd_wr_text_line2,
            i_dat_ascii_line1      => i_dat_ascii_line1,
            i_dat_ascii_line2      => i_dat_ascii_line2
        );

    -- Stand-alone SPI bus driver for a single bus-peripheral.
    u_pmod_generic_spi_solo : entity work.pmod_generic_spi_solo(moore_fsm_recursive)
        generic map (
            parm_ext_spi_clk_ratio => parm_ext_spi_clk_ratio,
            parm_tx_len_bits       => c_pmod_cls_tx_len_bits,
            parm_wait_cyc_bits     => c_pmod_cls_wait_cyc_bits,
            parm_rx_len_bits       => c_pmod_cls_rx_len_bits
        )
        port map (
            eo_sck_o        => sio_cls_sck_fsm_o,
            eo_sck_t        => sio_cls_sck_fsm_t,
            eo_csn_o        => sio_cls_csn_fsm_o,
            eo_csn_t        => sio_cls_csn_fsm_t,
            eo_copi_o       => sio_cls_copi_fsm_o,
            eo_copi_t       => sio_cls_copi_fsm_t,
            ei_cipo_i       => sio_cls_cipo_sync_i,
            i_ext_spi_clk_x => i_clk_20mhz,
            i_srst          => i_rst_20mhz,
            i_spi_ce_4x     => i_ce_2_5mhz,
            i_go_stand      => s_cls_go_stand,
            o_spi_idle      => s_cls_spi_idle,
            i_tx_len        => s_cls_tx_len,
            i_wait_cyc      => s_cls_wait_cyc,
            i_rx_len        => s_cls_rx_len,
            i_tx_data       => s_cls_tx_data,
            i_tx_enqueue    => s_cls_tx_enqueue,
            o_tx_ready      => s_cls_tx_ready,
            o_rx_data       => s_cls_rx_data,
            i_rx_dequeue    => s_cls_rx_dequeue,
            o_rx_valid      => s_cls_rx_valid,
            o_rx_avail      => s_cls_rx_avail
        );

end architecture rtl;
--------------------------------------------------------------------------------
