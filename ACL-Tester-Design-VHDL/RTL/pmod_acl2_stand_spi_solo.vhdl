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
-- \file pmod_acl2_stand_spi_solo.vhdl
--
-- \brief A custom driver to operate the PMOD ACL2 accelerometer with ADXL362,
-- that relies upon \ref pmod_generic_spi_solo to implement the Standard SPI
-- interface.
--
-- \description TODO: review comments of this file's FSM.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pmod_stand_spi_solo_pkg.all;
--------------------------------------------------------------------------------
package pmod_acl2_stand_spi_solo_pkg is
    -- ADXL362 command bytes.
    constant c_adxl362_cmd_write : std_logic_vector(7 downto 0) := x"0A";
    constant c_adxl362_cmd_read  : std_logic_vector(7 downto 0) := x"0B";
    constant c_adxl362_cmd_fifo  : std_logic_vector(7 downto 0) := x"0D";

    -- ADXL362 configurable register areas according to Applications section of the
    -- datasheeet: the starting address of these sections.
    constant c_adxl362_addr_cfg0 : std_logic_vector(7 downto 0) := x"20";
    constant c_adxl362_addr_cfg1 : std_logic_vector(7 downto 0) := x"27";
    constant c_adxl362_addr_cfg2 : std_logic_vector(7 downto 0) := x"28";
    constant c_adxl362_addr_cfg3 : std_logic_vector(7 downto 0) := x"2A";
    constant c_adxl362_addr_cfg4 : std_logic_vector(7 downto 0) := x"2C";
    constant c_adxl362_addr_cfg5 : std_logic_vector(7 downto 0) := x"2D";
    constant c_adxl362_addr_8reg : std_logic_vector(7 downto 0) := x"0E";
    constant c_adxl362_addr_stat : std_logic_vector(7 downto 0) := x"0B";
    constant c_adxl362_addr_sr   : std_logic_vector(7 downto 0) := x"1F";
    constant c_adxl362_data_sr   : std_logic_vector(7 downto 0) := x"52";

    -- Count of bytes to TX and count of bytes to RX, for each operation of the
    -- state machine.
    constant c_tx_ax_cfg0_length    : natural := 2 + 7;
    constant c_tx_ax_cfg1_length    : natural := 2 + 1;
    constant c_tx_ax_cfg2_length    : natural := 2 + 2;
    constant c_tx_ax_cfg3_length    : natural := 2 + 2;
    constant c_tx_ax_cfg4_length    : natural := 2 + 1;
    constant c_tx_ax_cfg5_length    : natural := 2 + 1;
    constant c_tx_ax_sr_length      : natural := 2 + 1;
    constant c_tx_ax_readmm_length  : natural := 2;
    constant c_rx_ax_readmm_length  : natural := 8;
    constant c_tx_ax_clearmm_length : natural := 2;
    constant c_rx_ax_clearmm_length : natural := 1;
    constant c_tx_ax_readlm_length  : natural := 2;
    constant c_rx_ax_readlm_length  : natural := 8;
    constant c_tx_ax_clearlm_length : natural := 2;
    constant c_rx_ax_clearlm_length : natural := 1;


    ----------------------------------------------------------------------------
    -- register values for Linked Mode operation
    --

    -- 0x20 : 0x26
    -- THRESH_ACT_L, THRESH_ACT_H, TIME_ACT, THRESH_INACT_L, THRESH_INACT_H,
    -- TIME_INACT_L, TIME_INACT_H
    constant c_tx_ax_cfg0_lm : t_pmod_acl2_reg_7 :=
        x"20" & x"00" & x"64" & x"1A" & x"00" &
        x"64" & x"00";

    -- 0x27
    -- ACT_INACT_CTL
    constant c_tx_ax_cfg1_lm : t_pmod_acl2_reg_1 :=
        "00011111";

    -- 0x28 : 0x29
    -- FIFO_CONTROL, FIFO_SAMPLES
    constant c_tx_ax_cfg2_lm : t_pmod_acl2_reg_2 :=
        "00000000" & "00000000";

    -- 0x2A : 0x2B
    -- INTMAP1, INTMAP2
    constant c_tx_ax_cfg3_lm : t_pmod_acl2_reg_2 :=
        x"20" & x"10";

    -- 0x2C
    -- FILTER_CTL
    constant c_tx_ax_cfg4_lm : t_pmod_acl2_reg_1 :=
        "00010011";

    -- 0x2D
    -- POWER_CTL
    constant c_tx_ax_cfg5_lm : t_pmod_acl2_reg_1 :=
        "00100010";

    ----------------------------------------------------------------------------
    -- register values for Measurement Mode operation
    --

    -- 0x20 : 0x26
    -- THRESH_ACT_L, THRESH_ACT_H, TIME_ACT, THRESH_INACT_L, THRESH_INACT_H,
    -- TIME_INACT_L, TIME_INACT_H
    constant c_tx_ax_cfg0_mm : t_pmod_acl2_reg_7 :=
        x"14" & x"00" & x"64" & x"10" & x"00" &
        x"64" & x"00";

    -- 0x27
    -- ACT_INACT_CTL
    constant c_tx_ax_cfg1_mm : t_pmod_acl2_reg_1 :=
        "00000101";

    -- 0x28 : 0x29
    -- FIFO_CONTROL, FIFO_SAMPLES
    constant c_tx_ax_cfg2_mm : t_pmod_acl2_reg_2 :=
        "00000000" & "00000000";

    -- 0x2A : 0x2B
    -- INTMAP1, INTMAP2
    constant c_tx_ax_cfg3_mm : t_pmod_acl2_reg_2 :=
        x"01" & x"00";

    -- 0x2C
    -- FILTER_CTL
    constant c_tx_ax_cfg4_mm : t_pmod_acl2_reg_1 :=
        "00010011";

    -- 0x2D
    -- POWER_CTL
    constant c_tx_ax_cfg5_mm : t_pmod_acl2_reg_1 :=
        "00100010";

end package pmod_acl2_stand_spi_solo_pkg;
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pmod_stand_spi_solo_pkg.all;
use work.pmod_acl2_stand_spi_solo_pkg.all;
--------------------------------------------------------------------------------
entity pmod_acl2_stand_spi_solo is
    generic(
        -- Disable or enable fast FSM delays for simulation instead of implementation.
        parm_fast_simulation : integer := 0;
        -- Actual frequency in Hz of \ref i_ext_spi_clk_4x
        parm_FCLK : natural := 20_000_000
    );
    port(
        -- system clock and synchronous reset
        i_ext_spi_clk_x : in std_logic;
        i_srst          : in std_logic;
        i_spi_ce_4x     : in std_logic;
        -- interrupt lines of the PMOD ACL2
        ei_int1 : in std_logic;
        ei_int2 : in std_logic;
        -- system interface to the \ref pmod_generic_spi_solo module.
        o_go_stand : out std_logic;
        i_spi_idle : in  std_logic;
        o_tx_len   : out t_pmod_acl2_tx_len;
        o_wait_cyc : out t_pmod_acl2_wait_cyc;
        o_rx_len   : out t_pmod_acl2_rx_len;
        -- TX FIFO interface to the \ref pmod_generic_spi_solo module.
        o_tx_data    : out t_pmod_acl2_data_byte;
        o_tx_enqueue : out std_logic;
        i_tx_ready   : in  std_logic;
        -- RX FIFO interface to the \ref pmod_generic_spi_solo module.
        i_rx_data    : in  t_pmod_acl2_data_byte;
        o_rx_dequeue : out std_logic;
        i_rx_valid   : in  std_logic;
        i_rx_avail   : in  std_logic;
        -- FPGA system interface to ACL2 operation
        o_command_ready         : out std_logic;
        i_cmd_init_linked_mode  : in  std_logic;
        i_cmd_start_linked_mode : in  std_logic;
        i_cmd_init_measur_mode  : in  std_logic;
        i_cmd_start_measur_mode : in  std_logic;
        i_cmd_soft_reset_acl2   : in  std_logic;
        -- measurement data streaming output of the accelerometer
        o_rd_data_stream      : out t_pmod_acl2_data_byte;
        o_rd_data_byte_valid  : out std_logic;
        o_rd_data_group_valid : out std_logic;
        -- data status of accelerometer
        o_reg_status : out t_pmod_acl2_reg_1;
        -- run-time dynamic configuration of Linked Mode
        i_tx_ax_cfg0_lm : in t_pmod_acl2_reg_7
    );
end entity pmod_acl2_stand_spi_solo;
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
architecture moore_fsm_recursive of pmod_acl2_stand_spi_solo is
    -- Timer signals and constants
    -- Boot time should be in hundreds of milliseconds as the ADXL362 lists on
    -- page 5 of datasheet Rev. F that the Power-Up to Standby time is
    -- 5 milliseconds typical, and does not list a maximum time.
    constant c_t_adx1362_boot_fast_sim : natural := parm_FCLK / 1000 * 1;
    constant c_t_adx1362_boot          : natural := parm_FCLK / 1000 * 100;
    constant c_tmax                    : natural := c_t_adx1362_boot - 1;
    signal s_t                         : natural range 0 to c_tmax;

    -- Driver FSM state declarations
    type t_acl2_drv_state is (ST_DRV_BOOT0, ST_DRV_IDLE0, ST_DRV_INIT_LM, ST_DRV_INIT_MM,
            ST_DRV_WR_AX_CFG0_CMD, ST_DRV_WR_AX_CFG0_ADDR, ST_DRV_WR_AX_CFG0_DATA, ST_DRV_WAIT_AX_CFG0,
            ST_DRV_WR_AX_CFG1_CMD, ST_DRV_WR_AX_CFG1_ADDR, ST_DRV_WR_AX_CFG1_DATA, ST_DRV_WAIT_AX_CFG1,
            ST_DRV_WR_AX_CFG2_CMD, ST_DRV_WR_AX_CFG2_ADDR, ST_DRV_WR_AX_CFG2_DATA, ST_DRV_WAIT_AX_CFG2,
            ST_DRV_WR_AX_CFG3_CMD, ST_DRV_WR_AX_CFG3_ADDR, ST_DRV_WR_AX_CFG3_DATA, ST_DRV_WAIT_AX_CFG3,
            ST_DRV_WR_AX_CFG4_CMD, ST_DRV_WR_AX_CFG4_ADDR, ST_DRV_WR_AX_CFG4_DATA, ST_DRV_WAIT_AX_CFG4,
            ST_DRV_WR_AX_CFG5_CMD, ST_DRV_WR_AX_CFG5_ADDR, ST_DRV_WR_AX_CFG5_DATA, ST_DRV_WAIT_AX_CFG5,
            ST_DRV_IDLE1,
            ST_DRV_WAIT_DR_INT1, ST_DRV_READ_MEASU_CMD, ST_DRV_READ_MEASU_ADDR, ST_DRV_READ_MEASU_DATA,
            ST_DRV_READ_WAIT0, ST_DRV_CLEAR_MEASU_CMD, ST_DRV_CLEAR_MEASU_ADDR, ST_DRV_CLEAR_MEASU_DATA,
            ST_DRV_READ_WAIT1, ST_DRV_READ_WAIT2,
            ST_DRV_WAIT_AT_INT1, ST_DRV_READ_INACT0_CMD, ST_DRV_READ_INACT0_ADDR, ST_DRV_READ_INACT0_DATA,
            ST_DRV_READ_WAIT3, ST_DRV_CLEAR_AWAKE0_CMD, ST_DRV_CLEAR_AWAKE0_ADDR, ST_DRV_CLEAR_AWAKE0_DATA,
            ST_DRV_READ_WAIT4, ST_DRV_READ_WAIT5,
            ST_DRV_WAIT_AT_INT2, ST_DRV_READ_ACT0_CMD, ST_DRV_READ_ACT0_ADDR, ST_DRV_READ_ACT0_DATA,
            ST_DRV_READ_WAIT6, ST_DRV_CLEAR_AWAKE1_CMD, ST_DRV_CLEAR_AWAKE1_ADDR, ST_DRV_CLEAR_AWAKE1_DATA,
            ST_DRV_READ_WAIT7, ST_DRV_READ_WAIT8,
            ST_DRV_SOFTRESET_CMD, ST_DRV_SOFTRESET_ADDR, ST_DRV_SOFTRESET_DATA, ST_DRV_SOFTRESET_WAIT9);

    signal s_acl2_drv_pr_state : t_acl2_drv_state := ST_DRV_BOOT0;
    signal s_acl2_drv_nx_state : t_acl2_drv_state := ST_DRV_BOOT0;

    -- Xilinx attributes for Auto encoding of the FSM and safe state is Default
    -- State.
    attribute fsm_encoding                          : string;
    attribute fsm_safe_state                        : string;
    attribute fsm_encoding of s_acl2_drv_pr_state   : signal is "auto";
    attribute fsm_safe_state of s_acl2_drv_pr_state : signal is "default_state";

    signal s_tx_ax_cfg0_val : t_pmod_acl2_reg_7;
    signal s_tx_ax_cfg0_aux : t_pmod_acl2_reg_7;
    signal s_tx_ax_cfg1_val : t_pmod_acl2_reg_1;
    signal s_tx_ax_cfg1_aux : t_pmod_acl2_reg_1;
    signal s_tx_ax_cfg2_val : t_pmod_acl2_reg_2;
    signal s_tx_ax_cfg2_aux : t_pmod_acl2_reg_2;
    signal s_tx_ax_cfg3_val : t_pmod_acl2_reg_2;
    signal s_tx_ax_cfg3_aux : t_pmod_acl2_reg_2;
    signal s_tx_ax_cfg4_val : t_pmod_acl2_reg_1;
    signal s_tx_ax_cfg4_aux : t_pmod_acl2_reg_1;
    signal s_tx_ax_cfg5_val : t_pmod_acl2_reg_1;
    signal s_tx_ax_cfg5_aux : t_pmod_acl2_reg_1;
    signal s_byte_index_val : natural range 0 to 255;
    signal s_byte_index_aux : natural range 0 to 255;
    signal s_reg_status_val : t_pmod_acl2_reg_1;
    signal s_reg_status_aux : t_pmod_acl2_reg_1;
begin

    o_reg_status <= s_reg_status_aux;

    -- Timer 1 (Strategy #1), for timing the boot wait for PMOD ACL2 communication
    p_timer_1 : process(i_ext_spi_clk_x)
    begin
        if rising_edge(i_ext_spi_clk_x) then
            if (i_srst = '1') then
                s_t <= 0;
            elsif (i_spi_ce_4x = '1') then
                if (s_acl2_drv_pr_state /= s_acl2_drv_nx_state) then
                    s_t <= 0;
                elsif (s_t < c_tmax) then
                    s_t <= s_t + 1;
                end if;
            end if;
        end if;
    end process p_timer_1;

    -- FSM state register plus auxiliary registers, for propagating the next state
    -- as well as the next recursive auxiliary register value for use within
    -- one or more state combinatorial logic decisions.
    p_fsm_state_aux : process(i_ext_spi_clk_x)
    begin
        if rising_edge(i_ext_spi_clk_x) then
            if (i_srst = '1') then
                s_acl2_drv_pr_state <= ST_DRV_BOOT0;

                s_tx_ax_cfg0_aux <= (others => '0');
                s_tx_ax_cfg1_aux <= (others => '0');
                s_tx_ax_cfg2_aux <= (others => '0');
                s_tx_ax_cfg3_aux <= (others => '0');
                s_tx_ax_cfg4_aux <= (others => '0');
                s_tx_ax_cfg5_aux <= (others => '0');
                s_byte_index_aux <= 0;
                s_reg_status_aux <= (others => '0');

            elsif (i_spi_ce_4x = '1') then
                s_acl2_drv_pr_state <= s_acl2_drv_nx_state;

                s_tx_ax_cfg0_aux <= s_tx_ax_cfg0_val;
                s_tx_ax_cfg1_aux <= s_tx_ax_cfg1_val;
                s_tx_ax_cfg2_aux <= s_tx_ax_cfg2_val;
                s_tx_ax_cfg3_aux <= s_tx_ax_cfg3_val;
                s_tx_ax_cfg4_aux <= s_tx_ax_cfg4_val;
                s_tx_ax_cfg5_aux <= s_tx_ax_cfg5_val;
                s_byte_index_aux <= s_byte_index_val;
                s_reg_status_aux <= s_reg_status_val;
            end if;
        end if;
    end process p_fsm_state_aux;

    -- FSM combinatorial logic providing multiple outputs, non-defaults assigned
    -- in every state, as well as changes in auxiliary values, and calculation
    -- of the next FSM state. Refer to the FSM state machine drawings.
    p_fsm_comb : process(s_acl2_drv_pr_state,
            s_tx_ax_cfg0_aux, s_tx_ax_cfg1_aux, s_tx_ax_cfg2_aux,
            s_tx_ax_cfg3_aux, s_tx_ax_cfg4_aux, s_tx_ax_cfg5_aux,
            s_byte_index_aux, s_reg_status_aux, ei_int1, ei_int2,
            i_cmd_start_measur_mode, i_cmd_start_linked_mode,
            i_cmd_init_measur_mode, i_cmd_init_linked_mode,
            i_cmd_soft_reset_acl2,
            i_tx_ready, i_rx_avail, i_rx_valid, i_rx_data,
            i_spi_idle, s_t,
            i_tx_ax_cfg0_lm)
    begin
        -- default values for all signals
        o_command_ready       <= '0';
        o_tx_data             <= x"00";
        o_tx_enqueue          <= '0';
        o_tx_len              <= std_logic_vector(to_unsigned(0, o_tx_len'length));
        o_rx_len              <= std_logic_vector(to_unsigned(0, o_rx_len'length));
        o_wait_cyc            <= std_logic_vector(to_unsigned(0, o_wait_cyc'length));
        o_rx_dequeue          <= '0';
        o_go_stand            <= '0';
        o_rd_data_stream      <= x"00";
        o_rd_data_byte_valid  <= '0';
        o_rd_data_group_valid <= '0';
        s_tx_ax_cfg0_val      <= s_tx_ax_cfg0_aux;
        s_tx_ax_cfg1_val      <= s_tx_ax_cfg1_aux;
        s_tx_ax_cfg2_val      <= s_tx_ax_cfg2_aux;
        s_tx_ax_cfg3_val      <= s_tx_ax_cfg3_aux;
        s_tx_ax_cfg4_val      <= s_tx_ax_cfg4_aux;
        s_tx_ax_cfg5_val      <= s_tx_ax_cfg5_aux;
        s_byte_index_val      <= s_byte_index_aux;
        s_reg_status_val      <= s_reg_status_aux;

        case (s_acl2_drv_pr_state) is
            when ST_DRV_INIT_LM =>
                -- Load auxiliary registers with Linked Mode configuration.
                s_tx_ax_cfg0_val <= i_tx_ax_cfg0_lm;
                s_tx_ax_cfg1_val <= c_tx_ax_cfg1_lm;
                s_tx_ax_cfg2_val <= c_tx_ax_cfg2_lm;
                s_tx_ax_cfg3_val <= c_tx_ax_cfg3_lm;
                s_tx_ax_cfg4_val <= c_tx_ax_cfg4_lm;
                s_tx_ax_cfg5_val <= c_tx_ax_cfg5_lm;

                s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG0_CMD;

            when ST_DRV_INIT_MM =>
                -- Load auxiliary registers with Measurement Mode configuration.
                s_tx_ax_cfg0_val <= c_tx_ax_cfg0_mm;
                s_tx_ax_cfg1_val <= c_tx_ax_cfg1_mm;
                s_tx_ax_cfg2_val <= c_tx_ax_cfg2_mm;
                s_tx_ax_cfg3_val <= c_tx_ax_cfg3_mm;
                s_tx_ax_cfg4_val <= c_tx_ax_cfg4_mm;
                s_tx_ax_cfg5_val <= c_tx_ax_cfg5_mm;

                s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG0_CMD;

            when ST_DRV_WR_AX_CFG0_CMD =>
                -- Load first byte, command WRITE, to TX FIFO.
                o_tx_data    <= c_adxl362_cmd_write;
                o_tx_enqueue <= i_tx_ready;
                o_tx_len     <= std_logic_vector(to_unsigned(c_tx_ax_cfg0_length, o_tx_len'length));

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG0_ADDR;
                else
                    -- o_tx_enqueue <= '0';
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG0_CMD;
                end if;

            when ST_DRV_WR_AX_CFG0_ADDR =>
                -- Load second byte, starting address for Configuration 0 byte
                -- sequence, to TX FIFO
                o_tx_data        <= c_adxl362_addr_cfg0;
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_cfg0_length, o_tx_len'length));
                s_byte_index_val <= (c_tx_ax_cfg0_length - 2);

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG0_DATA;
                else
                    -- o_tx_enqueue <= '0';
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG0_ADDR;
                end if;

            when ST_DRV_WR_AX_CFG0_DATA =>
                -- Load \ref c_tx_ax_cfg0_length - 2 count of register WRITE data bytes,
                -- and then trigger the Standard SPI operation.
                o_tx_data        <= s_tx_ax_cfg0_aux(((s_byte_index_aux * 8) - 1) downto ((s_byte_index_aux - 1) * 8));
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_cfg0_length, o_tx_len'length));
                o_go_stand       <= '1'                    when (i_tx_ready = '1') and (s_byte_index_aux <= 1) else '0';
                s_byte_index_val <= (s_byte_index_aux - 1) when (i_tx_ready = '1') else s_byte_index_aux;

                if ((i_tx_ready = '1') and (s_byte_index_aux <= 1)) then
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AX_CFG0;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG0_DATA;
                end if;

            when ST_DRV_WAIT_AX_CFG0 =>
                -- Wait for the SPI operation to complete and return to IDLE
                o_tx_len <= std_logic_vector(to_unsigned(c_tx_ax_cfg0_length, o_tx_len'length));

                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG1_CMD;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AX_CFG0;
                end if;

            when ST_DRV_WR_AX_CFG1_CMD =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data    <= c_adxl362_cmd_write;
                o_tx_enqueue <= i_tx_ready;
                o_tx_len     <= std_logic_vector(to_unsigned(c_tx_ax_cfg1_length, o_tx_len'length));

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG1_ADDR;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG1_CMD;
                end if;

            when ST_DRV_WR_AX_CFG1_ADDR =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data        <= c_adxl362_addr_cfg1;
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_cfg1_length, o_tx_len'length));
                s_byte_index_val <= (c_tx_ax_cfg1_length - 2);

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG1_DATA;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG1_ADDR;
                end if;

            when ST_DRV_WR_AX_CFG1_DATA =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data        <= s_tx_ax_cfg1_aux(((s_byte_index_aux * 8) - 1) downto ((s_byte_index_aux - 1) * 8));
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_cfg1_length, o_tx_len'length));
                o_go_stand       <= '1'                    when (i_tx_ready = '1') and (s_byte_index_aux <= 1) else '0';
                s_byte_index_val <= (s_byte_index_aux - 1) when (i_tx_ready = '1') else s_byte_index_aux;

                if ((i_tx_ready = '1') and (s_byte_index_aux <= 1)) then
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AX_CFG1;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG1_DATA;
                end if;

            when ST_DRV_WAIT_AX_CFG1 =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_len <= std_logic_vector(to_unsigned(c_tx_ax_cfg1_length, o_tx_len'length));

                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG2_CMD;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AX_CFG1;
                end if;

            when ST_DRV_WR_AX_CFG2_CMD =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data    <= c_adxl362_cmd_write;
                o_tx_enqueue <= i_tx_ready;
                o_tx_len     <= std_logic_vector(to_unsigned(c_tx_ax_cfg2_length, o_tx_len'length));

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG2_ADDR;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG2_CMD;
                end if;

            when ST_DRV_WR_AX_CFG2_ADDR =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data        <= c_adxl362_addr_cfg2;
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_cfg2_length, o_tx_len'length));
                s_byte_index_val <= (c_tx_ax_cfg2_length - 2);

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG2_DATA;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG2_ADDR;
                end if;

            when ST_DRV_WR_AX_CFG2_DATA =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data        <= s_tx_ax_cfg2_aux(((s_byte_index_aux * 8) - 1) downto ((s_byte_index_aux - 1) * 8));
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_cfg2_length, o_tx_len'length));
                o_go_stand       <= '1'                    when (i_tx_ready = '1') and (s_byte_index_aux <= 1) else '0';
                s_byte_index_val <= (s_byte_index_aux - 1) when (i_tx_ready = '1') else s_byte_index_aux;

                if ((i_tx_ready = '1') and (s_byte_index_aux <= 1)) then
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AX_CFG2;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG2_DATA;
                end if;

            when ST_DRV_WAIT_AX_CFG2 =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_len <= std_logic_vector(to_unsigned(c_tx_ax_cfg2_length, o_tx_len'length));

                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG3_CMD;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AX_CFG2;
                end if;

            when ST_DRV_WR_AX_CFG3_CMD =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data    <= c_adxl362_cmd_write;
                o_tx_enqueue <= i_tx_ready;
                o_tx_len     <= std_logic_vector(to_unsigned(c_tx_ax_cfg3_length, o_tx_len'length));

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG3_ADDR;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG3_CMD;
                end if;

            when ST_DRV_WR_AX_CFG3_ADDR =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data        <= c_adxl362_addr_cfg3;
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_cfg3_length, o_tx_len'length));
                s_byte_index_val <= (c_tx_ax_cfg3_length - 2);

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG3_DATA;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG3_ADDR;
                end if;

            when ST_DRV_WR_AX_CFG3_DATA =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data        <= s_tx_ax_cfg3_aux(((s_byte_index_aux * 8) - 1) downto ((s_byte_index_aux - 1) * 8));
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_cfg3_length, o_tx_len'length));
                o_go_stand       <= '1'                    when (i_tx_ready = '1') and (s_byte_index_aux <= 1) else '0';
                s_byte_index_val <= (s_byte_index_aux - 1) when (i_tx_ready = '1') else s_byte_index_aux;

                if ((i_tx_ready = '1') and (s_byte_index_aux <= 1)) then
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AX_CFG3;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG3_DATA;
                end if;

            when ST_DRV_WAIT_AX_CFG3 =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_len <= std_logic_vector(to_unsigned(c_tx_ax_cfg3_length, o_tx_len'length));

                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG4_CMD;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AX_CFG3;
                end if;

            when ST_DRV_WR_AX_CFG4_CMD =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data    <= c_adxl362_cmd_write;
                o_tx_enqueue <= i_tx_ready;
                o_tx_len     <= std_logic_vector(to_unsigned(c_tx_ax_cfg4_length, o_tx_len'length));

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG4_ADDR;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG4_CMD;
                end if;

            when ST_DRV_WR_AX_CFG4_ADDR =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data        <= c_adxl362_addr_cfg4;
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_cfg4_length, o_tx_len'length));
                s_byte_index_val <= (c_tx_ax_cfg4_length - 2);

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG4_DATA;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG4_ADDR;
                end if;

            when ST_DRV_WR_AX_CFG4_DATA =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data        <= s_tx_ax_cfg4_aux(((s_byte_index_aux * 8) - 1) downto ((s_byte_index_aux - 1) * 8));
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_cfg4_length, o_tx_len'length));
                o_go_stand       <= '1'                    when (i_tx_ready = '1') and (s_byte_index_aux <= 1) else '0';
                s_byte_index_val <= (s_byte_index_aux - 1) when (i_tx_ready = '1') else s_byte_index_aux;

                if ((i_tx_ready = '1') and (s_byte_index_aux <= 1)) then
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AX_CFG4;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG4_DATA;
                end if;

            when ST_DRV_WAIT_AX_CFG4 =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_len <= std_logic_vector(to_unsigned(c_tx_ax_cfg4_length, o_tx_len'length));

                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG5_CMD;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AX_CFG4;
                end if;

            when ST_DRV_WR_AX_CFG5_CMD =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data    <= c_adxl362_cmd_write;
                o_tx_enqueue <= i_tx_ready;
                o_tx_len     <= std_logic_vector(to_unsigned(c_tx_ax_cfg5_length, o_tx_len'length));

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG5_ADDR;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG5_CMD;
                end if;

            when ST_DRV_WR_AX_CFG5_ADDR =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data        <= c_adxl362_addr_cfg5;
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_cfg5_length, o_tx_len'length));
                s_byte_index_val <= (c_tx_ax_cfg5_length - 2);

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG5_DATA;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG5_ADDR;
                end if;

            when ST_DRV_WR_AX_CFG5_DATA =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_data        <= s_tx_ax_cfg5_aux(((s_byte_index_aux * 8) - 1) downto ((s_byte_index_aux - 1) * 8));
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_cfg5_length, o_tx_len'length));
                o_go_stand       <= '1'                    when (i_tx_ready = '1') and (s_byte_index_aux <= 1) else '0';
                s_byte_index_val <= (s_byte_index_aux - 1) when (i_tx_ready = '1') else s_byte_index_aux;

                if ((i_tx_ready = '1') and (s_byte_index_aux <= 1)) then
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AX_CFG5;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WR_AX_CFG5_DATA;
                end if;

            when ST_DRV_WAIT_AX_CFG5 =>
                -- Refer to the comments in the Configuration 0 sequence.
                o_tx_len <= std_logic_vector(to_unsigned(c_tx_ax_cfg5_length, o_tx_len'length));

                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_IDLE1;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AX_CFG5;
                end if;

            when ST_DRV_WAIT_DR_INT1 =>
                -- If the SOFT RESET command is held, the transition to SOFT RESET operation.
                -- If the Interrupt 1 is indicated (Data Ready status bit), then transition
                -- to reading the full measurement of X, Y, Z, Temp.
                -- Otherwise, wait for one of these two to occur.
                if (i_cmd_soft_reset_acl2 = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_SOFTRESET_CMD;
                elsif (ei_int1 = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_MEASU_CMD;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_DR_INT1;
                end if;

            when ST_DRV_READ_MEASU_CMD =>
                -- Load first byte, command READ, to TX FIFO.
                o_tx_data             <= c_adxl362_cmd_read;
                o_tx_enqueue          <= i_tx_ready;
                o_tx_len              <= std_logic_vector(to_unsigned(c_tx_ax_readmm_length, o_tx_len'length));
                o_rx_len              <= std_logic_vector(to_unsigned(c_rx_ax_readmm_length, o_rx_len'length));
                o_rd_data_group_valid <= '1';

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_MEASU_ADDR;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_MEASU_CMD;
                end if;

            when ST_DRV_READ_MEASU_ADDR =>
                -- Load second byte, starting address for Measurements 8-byte sequence, to TX FIFO.
                -- Then trigger the SPI bus operation.
                o_tx_data             <= c_adxl362_addr_8reg;
                o_tx_enqueue          <= i_tx_ready;
                o_tx_len              <= std_logic_vector(to_unsigned(c_tx_ax_readmm_length, o_tx_len'length));
                o_rx_len              <= std_logic_vector(to_unsigned(c_rx_ax_readmm_length, o_rx_len'length));
                o_go_stand            <= i_tx_ready;
                o_rd_data_group_valid <= '1';
                s_byte_index_val      <= c_rx_ax_readmm_length;

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_MEASU_DATA;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_MEASU_ADDR;
                end if;

            when ST_DRV_READ_MEASU_DATA =>
                -- Receive the eight bytes of measurment data from the SPI bus operation,
                -- and output the bytes one-at-a-time in a streaming pattern.
                o_tx_len              <= std_logic_vector(to_unsigned(c_tx_ax_readmm_length, o_tx_len'length));
                o_rx_len              <= std_logic_vector(to_unsigned(c_rx_ax_readmm_length, o_rx_len'length));
                o_rx_dequeue          <= i_rx_avail;
                o_rd_data_stream      <= i_rx_data;
                o_rd_data_byte_valid  <= i_rx_valid;
                o_rd_data_group_valid <= '1';
                s_byte_index_val      <= (s_byte_index_aux - 1) when (i_rx_valid = '1') else s_byte_index_aux;

                if ((i_rx_valid = '1') and (s_byte_index_aux <= 1)) then
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT0;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_MEASU_DATA;
                end if;

            when ST_DRV_READ_WAIT0 =>
                -- End the data stream GROUP signal, and wait for the SPI operation
                -- to return to IDLE.
                o_tx_len              <= std_logic_vector(to_unsigned(c_tx_ax_readmm_length, o_tx_len'length));
                o_rx_len              <= std_logic_vector(to_unsigned(c_rx_ax_readmm_length, o_rx_len'length));
                o_rd_data_group_valid <= '1';

                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_MEASU_CMD;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT0;
                end if;

            when ST_DRV_CLEAR_MEASU_CMD =>
                -- Start a clearing of the status register currently indicating
                -- DATA READY bit.
                -- Load the READ command first.
                o_tx_data    <= c_adxl362_cmd_read;
                o_tx_enqueue <= i_tx_ready;
                o_tx_len     <= std_logic_vector(to_unsigned(c_tx_ax_clearmm_length, o_tx_len'length));
                o_rx_len     <= std_logic_vector(to_unsigned(c_rx_ax_clearmm_length, o_rx_len'length));

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_MEASU_ADDR;
                else
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_MEASU_CMD;
                end if;

            when ST_DRV_CLEAR_MEASU_ADDR =>
                -- Next, load the STATUS REGISTER address and start the SPI
                -- bus operation.
                o_tx_data        <= c_adxl362_addr_stat;
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_clearmm_length, o_tx_len'length));
                o_rx_len         <= std_logic_vector(to_unsigned(c_rx_ax_clearmm_length, o_rx_len'length));
                o_go_stand       <= i_tx_ready;
                s_byte_index_val <= c_rx_ax_clearmm_length;

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_MEASU_DATA;
                else
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_MEASU_ADDR;
                end if;

            when ST_DRV_CLEAR_MEASU_DATA =>
                -- Receive a new value for the STATUS REGISTER byte.
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_clearmm_length, o_tx_len'length));
                o_rx_len         <= std_logic_vector(to_unsigned(c_rx_ax_clearmm_length, o_rx_len'length));
                o_rx_dequeue     <= i_rx_avail;
                s_byte_index_val <= (s_byte_index_aux - 1) when (i_rx_valid = '1') else s_byte_index_aux;
                s_reg_status_val <= i_rx_data              when (i_rx_valid = '1') else s_reg_status_aux;

                if (i_rx_valid = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT1;
                else
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_MEASU_DATA;
                end if;

            when ST_DRV_READ_WAIT1 =>
                -- After reading the STATUS REGISTER, wait for the SPI operation
                -- to return to IDLE.
                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT2;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT1;
                end if;

            when ST_DRV_READ_WAIT2 =>
                -- Reading the STATUS REGISTER should have cleared INT1 interrupt
                -- pin. If it did, transition to state to wait on interrupt.
                -- If it did not, try reading the STATUS REGISTER again.
                if (ei_int1 = '0') then
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_DR_INT1;
                else
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_MEASU_CMD;
                end if;

            when ST_DRV_WAIT_AT_INT1 =>
                -- If the SOFT RESET command is held, then transition to SOFT RESET operation.
                -- If the Interrupt 1 is indicated (Inactivity status bit), then transition
                -- to reading the full measurement of X, Y, Z, Temp.
                -- If the Interrupt 2 is indicated (Activity status bit), then transition
                -- to reading the full measurement of X, Y, Z, Temp.
                -- Otherwise, wait for one of these three to occur.
                if (i_cmd_soft_reset_acl2 = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_SOFTRESET_CMD;
                elsif (ei_int1 = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_INACT0_CMD;
                elsif (ei_int2 = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_ACT0_CMD;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AT_INT1;
                end if;

            when ST_DRV_READ_INACT0_CMD =>
                -- Load first byte, command READ, to TX FIFO.
                o_tx_data             <= c_adxl362_cmd_read;
                o_tx_enqueue          <= i_tx_ready;
                o_tx_len              <= std_logic_vector(to_unsigned(c_tx_ax_readlm_length, o_tx_len'length));
                o_rx_len              <= std_logic_vector(to_unsigned(c_rx_ax_readlm_length, o_rx_len'length));
                o_rd_data_group_valid <= '1';

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_INACT0_ADDR;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_INACT0_CMD;
                end if;

            when ST_DRV_READ_INACT0_ADDR =>
                -- Load second byte, starting address for Measurements 8-byte sequence, to TX FIFO.
                -- At the same time, trigger the SPI bus operation.
                o_tx_data             <= c_adxl362_addr_8reg;
                o_tx_enqueue          <= i_tx_ready;
                o_tx_len              <= std_logic_vector(to_unsigned(c_tx_ax_readlm_length, o_tx_len'length));
                o_rx_len              <= std_logic_vector(to_unsigned(c_rx_ax_readlm_length, o_rx_len'length));
                o_go_stand            <= i_tx_ready;
                o_rd_data_group_valid <= '1';
                s_byte_index_val      <= c_rx_ax_readlm_length;

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_INACT0_DATA;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_INACT0_ADDR;
                end if;

            when ST_DRV_READ_INACT0_DATA =>
                -- Receive the eight bytes of measurment data from the SPI bus operation,
                -- and output the bytes one-at-a-time in a streaming pattern.
                o_tx_len              <= std_logic_vector(to_unsigned(c_tx_ax_readlm_length, o_tx_len'length));
                o_rx_len              <= std_logic_vector(to_unsigned(c_rx_ax_readlm_length, o_rx_len'length));
                o_rx_dequeue          <= i_rx_avail;
                o_rd_data_stream      <= i_rx_data;
                o_rd_data_byte_valid  <= i_rx_valid;
                o_rd_data_group_valid <= '1';
                s_byte_index_val      <= (s_byte_index_aux - 1) when (i_rx_valid = '1') else s_byte_index_aux;

                if ((i_rx_valid = '1') and (s_byte_index_aux <= 1)) then
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT3;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_INACT0_DATA;
                end if;

            when ST_DRV_READ_WAIT3 =>
                -- End the data stream GROUP signal, and wait for the SPI operation
                -- to return to IDLE.
                o_tx_len              <= std_logic_vector(to_unsigned(c_tx_ax_readlm_length, o_tx_len'length));
                o_rx_len              <= std_logic_vector(to_unsigned(c_rx_ax_readlm_length, o_rx_len'length));
                o_rd_data_group_valid <= '1';

                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE0_CMD;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT3;
                end if;

            when ST_DRV_CLEAR_AWAKE0_CMD =>
                -- Start a clearing of the status register currently indicating
                -- INACTIVITY bit.
                -- Load the READ command first.
                o_tx_data    <= c_adxl362_cmd_read;
                o_tx_enqueue <= i_tx_ready;
                o_tx_len     <= std_logic_vector(to_unsigned(c_tx_ax_clearlm_length, o_tx_len'length));
                o_rx_len     <= std_logic_vector(to_unsigned(c_rx_ax_clearlm_length, o_rx_len'length));

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE0_ADDR;
                else
                    -- o_tx_enqueue <= '0';
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE0_CMD;
                end if;

            when ST_DRV_CLEAR_AWAKE0_ADDR =>
                -- Next, load the STATUS REGISTER address and start the SPI
                -- bus operation.
                o_tx_data        <= c_adxl362_addr_stat;
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_clearlm_length, o_tx_len'length));
                o_rx_len         <= std_logic_vector(to_unsigned(c_rx_ax_clearlm_length, o_rx_len'length));
                o_go_stand       <= i_tx_ready;
                s_byte_index_val <= c_rx_ax_clearmm_length;

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE0_DATA;
                else
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE0_ADDR;
                end if;

            when ST_DRV_CLEAR_AWAKE0_DATA =>
                -- Receive a new value for the STATUS REGISTER byte.
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_clearlm_length, o_tx_len'length));
                o_rx_len         <= std_logic_vector(to_unsigned(c_rx_ax_clearlm_length, o_rx_len'length));
                o_rx_dequeue     <= i_rx_avail;
                s_byte_index_val <= (s_byte_index_aux - 1) when (i_rx_valid = '1') else s_byte_index_aux;
                s_reg_status_val <= i_rx_data              when (i_rx_valid = '1') else s_reg_status_aux;

                if (i_rx_valid = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT4;
                else
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE0_DATA;
                end if;

            when ST_DRV_READ_WAIT4 =>
                -- After reading the STATUS REGISTER, which clears the interrupts,
                -- wait for the SPI operation to return to IDLE.
                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT5;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT4;
                end if;

            when ST_DRV_READ_WAIT5 =>
                -- Reading the STATUS REGISTER should have cleared INT1 interrupt
                -- pin. If it did, transition to state to wait on interrupt.
                -- If it did not, try reading the STATUS REGISTER again.
                if (ei_int1 = '0') then
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AT_INT2;
                else
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE0_CMD;
                end if;

            when ST_DRV_WAIT_AT_INT2 =>
                -- If the SOFT RESET command is held, then transition to SOFT RESET operation.
                -- If the Interrupt 2 is indicated (Activity status bit), then transition
                -- to reading the full measurement of X, Y, Z, Temp.
                -- If the Interrupt 1 is indicated (Inactivity status bit), then transition
                -- to reading the full measurement of X, Y, Z, Temp.
                -- Otherwise, wait for one of these three to occur.
                if (i_cmd_soft_reset_acl2 = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_SOFTRESET_CMD;
                elsif (ei_int2 = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_ACT0_CMD;
                elsif (ei_int1 = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_INACT0_CMD;
                else
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AT_INT2;
                end if;

            when ST_DRV_READ_ACT0_CMD =>
                -- Load first byte, command READ, to TX FIFO.
                o_tx_data             <= c_adxl362_cmd_read;
                o_tx_enqueue          <= i_tx_ready;
                o_tx_len              <= std_logic_vector(to_unsigned(c_tx_ax_readlm_length, o_tx_len'length));
                o_rx_len              <= std_logic_vector(to_unsigned(c_rx_ax_readlm_length, o_rx_len'length));
                o_rd_data_group_valid <= '1';

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_ACT0_ADDR;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_ACT0_CMD;
                end if;

            when ST_DRV_READ_ACT0_ADDR =>
                -- Load second byte, starting address for Measurements 8-byte sequence, to TX FIFO.
                -- At the same time, trigger the SPI bus operation.
                o_tx_data             <= c_adxl362_addr_8reg;
                o_tx_enqueue          <= i_tx_ready;
                o_tx_len              <= std_logic_vector(to_unsigned(c_tx_ax_readlm_length, o_tx_len'length));
                o_rx_len              <= std_logic_vector(to_unsigned(c_rx_ax_readlm_length, o_rx_len'length));
                o_go_stand            <= i_tx_ready;
                o_rd_data_group_valid <= '1';
                s_byte_index_val      <= c_rx_ax_readlm_length;

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_ACT0_DATA;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_ACT0_ADDR;
                end if;

            when ST_DRV_READ_ACT0_DATA =>
                -- Receive the eight bytes of measurment data from the SPI bus operation,
                -- and output the bytes one-at-a-time in a streaming pattern.
                o_tx_len              <= std_logic_vector(to_unsigned(c_tx_ax_readlm_length, o_tx_len'length));
                o_rx_len              <= std_logic_vector(to_unsigned(c_rx_ax_readlm_length, o_rx_len'length));
                o_rx_dequeue          <= i_rx_avail;
                o_rd_data_stream      <= i_rx_data;
                o_rd_data_byte_valid  <= i_rx_valid;
                o_rd_data_group_valid <= '1';
                s_byte_index_val      <= (s_byte_index_aux - 1) when (i_rx_valid = '1') else s_byte_index_aux;

                if ((i_rx_valid = '1') and (s_byte_index_aux <= 1)) then
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT6;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_ACT0_DATA;
                end if;

            when ST_DRV_READ_WAIT6 =>
                -- End the data stream GROUP signal, and wait for the SPI operation
                -- to return to IDLE.
                o_tx_len              <= std_logic_vector(to_unsigned(c_tx_ax_readlm_length, o_tx_len'length));
                o_rx_len              <= std_logic_vector(to_unsigned(c_rx_ax_readlm_length, o_rx_len'length));
                o_rd_data_group_valid <= '1';

                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE1_CMD;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT6;
                end if;

            when ST_DRV_CLEAR_AWAKE1_CMD =>
                -- Start a clearing of the status register currently indicating
                -- ACTIVITY bit.
                -- Load the READ command first.
                o_tx_data    <= c_adxl362_cmd_read;
                o_tx_enqueue <= i_tx_ready;
                o_tx_len     <= std_logic_vector(to_unsigned(c_tx_ax_clearlm_length, o_tx_len'length));
                o_rx_len     <= std_logic_vector(to_unsigned(c_rx_ax_clearlm_length, o_rx_len'length));

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE1_ADDR;
                else
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE1_CMD;
                end if;

            when ST_DRV_CLEAR_AWAKE1_ADDR =>
                -- Next, load the STATUS REGISTER address and start the SPI
                -- bus operation.
                o_tx_data        <= c_adxl362_addr_stat;
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_clearlm_length, o_tx_len'length));
                o_rx_len         <= std_logic_vector(to_unsigned(c_rx_ax_clearlm_length, o_rx_len'length));
                o_go_stand       <= i_tx_ready;
                s_byte_index_val <= c_rx_ax_clearmm_length;

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE1_DATA;
                else
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE1_ADDR;
                end if;

            when ST_DRV_CLEAR_AWAKE1_DATA =>
                -- Receive a new value for the STATUS REGISTER byte.
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_clearlm_length, o_tx_len'length));
                o_rx_len         <= std_logic_vector(to_unsigned(c_rx_ax_clearlm_length, o_rx_len'length));
                o_rx_dequeue     <= i_rx_avail;
                s_byte_index_val <= (s_byte_index_aux - 1) when (i_rx_valid = '1') else s_byte_index_aux;
                s_reg_status_val <= i_rx_data              when (i_rx_valid = '1') else s_reg_status_aux;

                if (i_rx_valid = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT7;
                else
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE1_DATA;
                end if;

            when ST_DRV_READ_WAIT7 =>
                -- After reading the STATUS REGISTER, which clears the interrupts,
                -- wait for the SPI operation to return to IDLE.
                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT8;
                else
                    s_acl2_drv_nx_state <= ST_DRV_READ_WAIT7;
                end if;

            when ST_DRV_READ_WAIT8 =>
                -- Reading the STATUS REGISTER should have cleared INT2 interrupt
                -- pin. If it did, transition to state to wait on interrupt.
                -- If it did not, try reading the STATUS REGISTER again.
                if (ei_int2 = '0') then
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AT_INT1;
                else
                    s_acl2_drv_nx_state <= ST_DRV_CLEAR_AWAKE1_CMD;
                end if;

            when ST_DRV_SOFTRESET_CMD =>
                -- Start the writing of the SOFT RESET byte to the SOFT RESET REGISTER.
                -- First, load the WRITE command.
                o_tx_data    <= c_adxl362_cmd_write;
                o_tx_enqueue <= i_tx_ready;
                o_tx_len     <= std_logic_vector(to_unsigned(c_tx_ax_sr_length, o_tx_len'length));

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_SOFTRESET_ADDR;
                else
                    s_acl2_drv_nx_state <= ST_DRV_SOFTRESET_CMD;
                end if;

            when ST_DRV_SOFTRESET_ADDR =>
                -- Next, load the address of the SOFT RESET REGISTER.
                o_tx_data        <= c_adxl362_addr_sr;
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_sr_length, o_tx_len'length));
                s_byte_index_val <= c_tx_ax_sr_length - 2;

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_SOFTRESET_DATA;
                else
                    s_acl2_drv_nx_state <= ST_DRV_SOFTRESET_ADDR;
                end if;

            when ST_DRV_SOFTRESET_DATA =>
                -- Finally, load the data value that is command to SOFT RESET,
                -- and at the same time trigger the SPI operation to start.
                o_tx_data        <= c_adxl362_data_sr;
                o_tx_enqueue     <= i_tx_ready;
                o_tx_len         <= std_logic_vector(to_unsigned(c_tx_ax_sr_length, o_tx_len'length));
                o_go_stand       <= i_tx_ready;
                s_byte_index_val <= (s_byte_index_aux - 1) when (i_tx_ready = '1') else s_byte_index_aux;

                if (i_tx_ready = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_SOFTRESET_WAIT9;
                else
                    s_acl2_drv_nx_state <= ST_DRV_SOFTRESET_DATA;
                end if;

            when ST_DRV_SOFTRESET_WAIT9 =>
                -- Wait for the SPI operation to return to IDLE. Then
                -- transition to the BOOT state to reboot the ADXL362.
                o_tx_len <= std_logic_vector(to_unsigned(c_tx_ax_sr_length, o_tx_len'length));

                if (i_spi_idle = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_BOOT0;
                else
                    s_acl2_drv_nx_state <= ST_DRV_SOFTRESET_WAIT9;
                end if;

            when ST_DRV_IDLE1 =>
                -- IDLE the state machine and wait for either a START LINKED MODE
                -- or START MESASUREMENT MODE command to transition. If transitioning
                -- to LINKED MODE, then wait on Inactivity and then Activity, back
                -- and forth. If transitioning to MEASUREMENT MODE, then wait for
                -- 100 Hz DATA READY interrupt.
                o_command_ready <= i_spi_idle;

                if (i_cmd_start_linked_mode = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_AT_INT1;
                elsif (i_cmd_start_measur_mode = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_WAIT_DR_INT1;
                else
                    s_acl2_drv_nx_state <= ST_DRV_IDLE1;
                end if;

            when ST_DRV_IDLE0 =>
                -- IDLE the state machine and wait for either a INIT LINKED MODE
                -- or INIT MESASUREMENT MODE command to transition. If transitioning
                -- to LINKED MODE, then run the configuration sequence with respective
                -- configuration settings. If transitioning to MEASUREMENT MODE, then
                -- run the configuration sequence with respective configuration
                -- settings.
                o_command_ready <= i_spi_idle;

                if (i_cmd_init_linked_mode = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_INIT_LM;
                elsif (i_cmd_init_measur_mode = '1') then
                    s_acl2_drv_nx_state <= ST_DRV_INIT_MM;
                else
                    s_acl2_drv_nx_state <= ST_DRV_IDLE0;
                end if;

            when others => -- ST_DRV_BOOT0
                           -- Wait \ref c_t_adx1362_boot time before talking with the ADXL362.
                           -- If behaviorial simulation and \ref parm_fast_simulation specified,
                           -- use a different timer constant
                if (parm_fast_simulation = 0) then
                    if (s_t = c_t_adx1362_boot - 1) then
                        s_acl2_drv_nx_state <= ST_DRV_IDLE0;
                    else
                        s_acl2_drv_nx_state <= ST_DRV_BOOT0;
                    end if;
                else
                    if (s_t = c_t_adx1362_boot_fast_sim - 1) then
                        s_acl2_drv_nx_state <= ST_DRV_IDLE0;
                    else
                        s_acl2_drv_nx_state <= ST_DRV_BOOT0;
                    end if;
                end if;
        end case;
    end process p_fsm_comb;

end architecture moore_fsm_recursive;
--------------------------------------------------------------------------------
