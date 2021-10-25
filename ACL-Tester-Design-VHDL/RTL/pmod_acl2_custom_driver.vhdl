--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------
-- \file pmod_acl2_custom_driver.vhdl
--
-- \brief A wrapper for the single Chip Select, Standard SPI modules
--        \ref pmod_acl2_stand_spi_solo and \ref pmod_generic_spi_solo ,
--        implementing a custom multi-mode operation of the PMOD ACL2 by
--        Digilent Inc with SPI bus communication and two GPIO level interrupts
--        input from the PMOD ACL2.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pmod_stand_spi_solo_pkg.all;
use work.pmod_acl2_stand_spi_solo_pkg.c_tx_ax_cfg0_lm;
use work.thresh_presets_pkg.all;
--------------------------------------------------------------------------------
entity pmod_acl2_custom_driver is
	generic(
		-- Disable or enable fast FSM delays for simulation instead of impelementation.
		parm_fast_simulation : integer := 0;
		-- Actual frequency in Hz of \ref i_clk_20mhz
		parm_FCLK : natural := 20_000_000;
		-- Ratio of i_ext_spi_clk_x to SPI sck bus output. */
		parm_ext_spi_clk_ratio : integer := 4
	);
	port(
		-- Clock and reset, with clock at 4 times the frequency of the SPI bus
		i_clk_20mhz : in std_logic;
		i_rst_20mhz : in std_logic;
		-- Outputs and inputs from the single SPI peripheral
		eo_sck_t  : out std_logic;
		eo_sck_o  : out std_logic;
		eo_csn_t  : out std_logic;
		eo_csn_o  : out std_logic;
		eo_copi_t : out std_logic;
		eo_copi_o : out std_logic;
		ei_cipo   : in  std_logic;
		ei_int1   : in  std_logic;
		ei_int2   : in  std_logic;
		-- Command ready indication and five possible commands to the driver
		o_command_ready         : out std_logic;
		i_cmd_init_linked_mode  : in  std_logic;
		i_cmd_start_linked_mode : in  std_logic;
		i_cmd_init_measur_mode  : in  std_logic;
		i_cmd_start_measur_mode : in  std_logic;
		i_cmd_soft_reset_acl2   : in  std_logic;
		-- Output of the measurements in a single vector, plus a valid pulse
		o_data_3axis_temp : out t_pmod_acl2_reg_8;
		o_data_valid      : out std_logic;
		-- Output of the most recently read single byte status register,
		-- without a valid pualse.
		o_reg_status : out t_pmod_acl2_reg_1;
		-- Debounced buttons input
		i_btn_deb : in std_logic_vector(1 downto 0);
		-- Active and Inactive preset enumeration value
		o_enum_active   : out std_logic_vector(3 downto 0);
		o_enum_inactive : out std_logic_vector(3 downto 0)
	);
end entity pmod_acl2_custom_driver;
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
architecture rtl of pmod_acl2_custom_driver is
	-- ACL2 SPI driver wiring to the Generic SPI driver.
	signal s_acl2_go_stand   : std_logic;
	signal s_acl2_spi_idle   : std_logic;
	signal s_acl2_tx_len     : t_pmod_acl2_tx_len;
	signal s_acl2_wait_cyc   : t_pmod_acl2_wait_cyc;
	signal s_acl2_rx_len     : t_pmod_acl2_rx_len;
	signal s_acl2_tx_data    : t_pmod_acl2_data_byte;
	signal s_acl2_tx_enqueue : std_logic;
	signal s_acl2_tx_ready   : std_logic;
	signal s_acl2_rx_data    : t_pmod_acl2_data_byte;
	signal s_acl2_rx_dequeue : std_logic;
	signal s_acl2_rx_valid   : std_logic;
	signal s_acl2_rx_avail   : std_logic;

	-- ACL2 SPI driver signals for streaming the 8 bytes of measurement values.
	signal s_acl2_rd_data_stream             : t_pmod_acl2_data_byte;
	signal s_acl2_rd_data_byte_valid         : std_logic;
	signal s_acl2_rd_data_group_valid        : std_logic;
	signal s_hex_3axis_temp_measurements_val : t_pmod_acl2_reg_8;
	signal s_hex_3axis_temp_measurements_aux : t_pmod_acl2_reg_8;

	-- ACL2 SPI outputs, FSM signals to register the SPI bus outputs for
	-- optimal timing closure and glitch minimization.
	signal sio_acl2_sck_fsm_o  : std_logic;
	signal sio_acl2_sck_fsm_t  : std_logic;
	signal sio_acl2_csn_fsm_o  : std_logic;
	signal sio_acl2_csn_fsm_t  : std_logic;
	signal sio_acl2_copi_fsm_o : std_logic;
	signal sio_acl2_copi_fsm_t : std_logic;

	-- ACL2 SPI input synchronizer signals, where the synchronizer is used to
	-- mitigate metastability.
	signal sio_acl2_cipo_meta_i : std_logic;
	signal sio_acl2_cipo_sync_i : std_logic;

	-- Debounced external interrupts.
	signal si_int1_debounced : std_logic;
	signal si_int2_debounced : std_logic;

	-- Experiment FSM state declarations.
	type t_stream_state is (ST_WAIT_GROUP, ST_WAIT_VALID, ST_DONE_CYCLE);

	signal s_stream_pr_state : t_stream_state := ST_WAIT_GROUP;
	signal s_stream_nx_state : t_stream_state := ST_WAIT_GROUP;
	-- Xilinx attributes for Auto encoding of the FSM and safe state is Default
	-- State.
	attribute fsm_encoding                        : string;
	attribute fsm_safe_state                      : string;
	attribute fsm_encoding of s_stream_pr_state   : signal is "gray";
	attribute fsm_safe_state of s_stream_pr_state : signal is "default_state";

	constant c_j_max : natural := 8;
	signal s_j_val   : natural range 0 to 15;
	signal s_j_aux   : natural range 0 to 15;

	-- One-shot conversion of button levels
	signal s_btn0_one_shot : std_logic;
	signal s_btn1_one_shot : std_logic;

	-- Presets binary encoding for the seven registers on the ADXL362 chip
	signal s_tx_ax_cfg0_lm : t_pmod_acl2_reg_7;
	signal s_tx_ax_cfg0_discard : t_pmod_acl2_reg_1;
begin

	-- One shot generation of Button 0
	u_one_shot_fsm_btn0 : entity work.one_shot_fsm(rtl)
		port map (
			x   => i_btn_deb(0),
			clk => i_clk_20mhz,
			rst => i_rst_20mhz,
			y   => s_btn0_one_shot
		);

	-- One shot generation of Button 1
	u_one_shot_fsm_btn1 : entity work.one_shot_fsm(rtl)
		port map (
			x   => i_btn_deb(1),
			clk => i_clk_20mhz,
			rst => i_rst_20mhz,
			y   => s_btn1_one_shot
		);

	-- Presets seletor for the Activity detection thresholds and timers
	u_thresh_presets_selector_active : entity work.thresh_presets_selector(rtl)
		generic map (
			parm_presets_config => c_thresh_presets_active_a
		)
		port map (
			i_clk_20mhz                 => i_clk_20mhz,
			i_rst_20mhz                 => i_rst_20mhz,
			i_btn_chg_preset            => s_btn0_one_shot,
			o_value_enum                => o_enum_active,
			o_value_thresh(7 downto 0)  => s_tx_ax_cfg0_lm((7*8-1) downto (6*8)),
			o_value_thresh(15 downto 8) => s_tx_ax_cfg0_lm((6*8-1) downto (5*8)),
			o_value_timer(7 downto 0)   => s_tx_ax_cfg0_lm((5*8-1) downto (4*8)),
			o_value_timer(15 downto 8)  => s_tx_ax_cfg0_discard
		);

	-- Presets seletor for the Activity detection thresholds and timers
	u_thresh_presets_selector_inactive : entity work.thresh_presets_selector(rtl)
		generic map (
			parm_presets_config => c_thresh_presets_inactive_a
		)
		port map (
			i_clk_20mhz                 => i_clk_20mhz,
			i_rst_20mhz                 => i_rst_20mhz,
			i_btn_chg_preset            => s_btn1_one_shot,
			o_value_enum                => o_enum_inactive,
			o_value_thresh(7 downto 0)  => s_tx_ax_cfg0_lm((4*8-1) downto (3*8)),
			o_value_thresh(15 downto 8) => s_tx_ax_cfg0_lm((3*8-1) downto (2*8)),
			o_value_timer(7 downto 0)   => s_tx_ax_cfg0_lm((2*8-1) downto (1*8)),
			o_value_timer(15 downto 8)  => s_tx_ax_cfg0_lm((1*8-1) downto (0*8))
		);

	-- Register the SPI output an extra 4x-SPI-clock clock cycle.
	p_reg_spi_fsm_out : process(i_clk_20mhz)
	begin
		if rising_edge(i_clk_20mhz) then
			eo_sck_o <= sio_acl2_sck_fsm_o;
			eo_sck_t <= sio_acl2_sck_fsm_t;

			eo_csn_o <= sio_acl2_csn_fsm_o;
			eo_csn_t <= sio_acl2_csn_fsm_t;

			eo_copi_o <= sio_acl2_copi_fsm_o;
			eo_copi_t <= sio_acl2_copi_fsm_t;
		end if;
	end process p_reg_spi_fsm_out;

	-- Double-register the SPI input at 4x-SPI-clock cycle to prevent metastability.
	p_sync_spi_in : process(i_clk_20mhz)
	begin
		if rising_edge(i_clk_20mhz) then
			sio_acl2_cipo_sync_i <= sio_acl2_cipo_meta_i;
			sio_acl2_cipo_meta_i <= ei_cipo;
		end if;
	end process p_sync_spi_in;

	-- Multiple mode driver to operate the PMOD ACL2 via a stand-alone SPI driver.
	u_pmod_acl2_stand_spi_solo : entity work.pmod_acl2_stand_spi_solo(moore_fsm_recursive)
		generic map (
			parm_fast_simulation => parm_fast_simulation,
			parm_FCLK            => parm_FCLK
		)
		port map (
			i_ext_spi_clk_x         => i_clk_20mhz,
			i_srst                  => i_rst_20mhz,
			i_spi_ce_4x             => '1', -- clock enable is held '1' as 20 MHz is 4x the SPI clock
			ei_int1                 => si_int1_debounced,
			ei_int2                 => si_int2_debounced,
			o_go_stand              => s_acl2_go_stand,
			i_spi_idle              => s_acl2_spi_idle,
			o_tx_len                => s_acl2_tx_len,
			o_wait_cyc              => s_acl2_wait_cyc,
			o_rx_len                => s_acl2_rx_len,
			o_tx_data               => s_acl2_tx_data,
			o_tx_enqueue            => s_acl2_tx_enqueue,
			i_tx_ready              => s_acl2_tx_ready,
			i_rx_data               => s_acl2_rx_data,
			o_rx_dequeue            => s_acl2_rx_dequeue,
			i_rx_valid              => s_acl2_rx_valid,
			i_rx_avail              => s_acl2_rx_avail,
			o_command_ready         => o_command_ready,
			i_cmd_init_linked_mode  => i_cmd_init_linked_mode,
			i_cmd_start_linked_mode => i_cmd_start_linked_mode,
			i_cmd_init_measur_mode  => i_cmd_init_measur_mode,
			i_cmd_start_measur_mode => i_cmd_start_measur_mode,
			i_cmd_soft_reset_acl2   => i_cmd_soft_reset_acl2,
			o_rd_data_stream        => s_acl2_rd_data_stream,
			o_rd_data_byte_valid    => s_acl2_rd_data_byte_valid,
			o_rd_data_group_valid   => s_acl2_rd_data_group_valid,
			o_reg_status            => o_reg_status,
			i_tx_ax_cfg0_lm         => s_tx_ax_cfg0_lm
		);

	-- Stand-alone SPI bus driver for a single bus-peripheral.
	u_pmod_generic_spi_solo : entity work.pmod_generic_spi_solo(moore_fsm_recursive)
		generic map (
			parm_ext_spi_clk_ratio => parm_ext_spi_clk_ratio,
			parm_tx_len_bits       => c_pmod_acl2_tx_len_bits,
			parm_wait_cyc_bits     => c_pmod_acl2_wait_cyc_bits,
			parm_rx_len_bits       => c_pmod_acl2_rx_len_bits
		)
		port map (
			eo_sck_o        => sio_acl2_sck_fsm_o,
			eo_sck_t        => sio_acl2_sck_fsm_t,
			eo_csn_o        => sio_acl2_csn_fsm_o,
			eo_csn_t        => sio_acl2_csn_fsm_t,
			eo_copi_o       => sio_acl2_copi_fsm_o,
			eo_copi_t       => sio_acl2_copi_fsm_t,
			ei_cipo_i       => sio_acl2_cipo_sync_i,
			i_ext_spi_clk_x => i_clk_20mhz,
			i_srst          => i_rst_20mhz,
			i_spi_ce_4x     => '1', -- 20 MHz is 4x the SPI speed, so CE is held '1'
			i_go_stand      => s_acl2_go_stand,
			o_spi_idle      => s_acl2_spi_idle,
			i_tx_len        => s_acl2_tx_len,
			i_wait_cyc      => s_acl2_wait_cyc,
			i_rx_len        => s_acl2_rx_len,
			i_tx_data       => s_acl2_tx_data,
			i_tx_enqueue    => s_acl2_tx_enqueue,
			o_tx_ready      => s_acl2_tx_ready,
			o_rx_data       => s_acl2_rx_data,
			i_rx_dequeue    => s_acl2_rx_dequeue,
			o_rx_valid      => s_acl2_rx_valid,
			o_rx_avail      => s_acl2_rx_avail
		);

	-- Synchronize and debounce the INT1 incoming signal from PMOD ACL2.
	u_extint_deb_int1 : entity work.ext_interrupt_debouncer(moore_fsm)
		port map (
			o_int_deb    => si_int1_debounced,
			i_clk_20mhz  => i_clk_20mhz,
			i_rst_20mhz  => i_rst_20mhz,
			ei_interrupt => ei_int1
		);

	-- Synchronize and debounce the INT2 incoming signal from PMOD ACL2.
	u_extint_deb_int2 : entity work.ext_interrupt_debouncer(moore_fsm)
		port map (
			o_int_deb    => si_int2_debounced,
			i_clk_20mhz  => i_clk_20mhz,
			i_rst_20mhz  => i_rst_20mhz,
			ei_interrupt => ei_int2
		);

	-- FSM states for streaming data from the PMOD ACL2 to a buffer from which the
	-- other logic reads to display the hexadecimal values of the X-Axis, Y-Axis,
	-- Z-Axis, Temperature.
	p_stream_fsm_state_aux : process(i_clk_20mhz)
	begin
		if rising_edge(i_clk_20mhz) then
			if (i_rst_20mhz = '1') then
				s_stream_pr_state <= ST_WAIT_GROUP;

				s_j_aux                           <= 0;
				s_hex_3axis_temp_measurements_aux <= (others => '0');
				o_data_3axis_temp                 <= (others => '0');
			else
				s_stream_pr_state <= s_stream_nx_state;

				s_j_aux                           <= s_j_val;
				s_hex_3axis_temp_measurements_aux <=
					s_hex_3axis_temp_measurements_val;

				if ((s_stream_pr_state = ST_DONE_CYCLE) and
						(s_stream_nx_state = ST_WAIT_GROUP)) then
					o_data_3axis_temp <= s_hex_3axis_temp_measurements_aux;
					o_data_valid      <= '1';
				else
					o_data_valid <= '0';
				end if;
			end if;
		end if;
	end process p_stream_fsm_state_aux;

	-- FSM Combinatorial for capturing streamed measurements from the PMOD ACL2
	-- driver output in order that a high level module may use the captured byte
	-- data to display either engineer-readable values from the ADXL362, or
	-- physical milli-g acceleration values in human-readable form. */
	-- Note that the \ref pmod_acl2_stand_spi_solo driver provides two pulses for
	-- reading the incoming measurement reading bytes from the PMOD ACL2. The
	-- GROUP VALID pulse lasts at an active value of one for the duration of 
	-- reading via SPI and outputting valid bytes. The BYTE VALID pulse lasts for
	-- exactly one SPI-4x-clock cycle during the valid value of a received byte
	-- that belongs to the group of bytes. In this way, the GROUP VALID restarts
	-- receipt of byte data; and the BYTE VALID indicates when to read a valid
	-- incoming byte.
	p_stream_fsm_comb : process(s_stream_pr_state, s_acl2_rd_data_stream, s_acl2_rd_data_group_valid,
			s_acl2_rd_data_byte_valid, s_j_aux, s_hex_3axis_temp_measurements_aux)
	begin
		case (s_stream_pr_state) is
			when ST_WAIT_VALID =>
				if (s_j_aux = c_j_max) then
					-- hold the byte count
					s_j_val <= s_j_aux;

					-- hold the 8 byte measurement value from shifting
					s_hex_3axis_temp_measurements_val <=
						s_hex_3axis_temp_measurements_aux;

					-- data is captured as valid on the exit of the next state,
					-- \ref ST_DONE_CYCLE so transition
					s_stream_nx_state <= ST_DONE_CYCLE;
				elsif (s_acl2_rd_data_byte_valid = '1') then
					-- count up the byte value
					s_j_val <= s_j_aux + 1;

					-- shift-in the new stream byte
					s_hex_3axis_temp_measurements_val <=
						s_hex_3axis_temp_measurements_aux((7*8-1) downto 0) &
						s_acl2_rd_data_stream;

					-- stay in this state for more captures
					s_stream_nx_state <= ST_WAIT_VALID;
				else
					-- hold the byte count
					s_j_val <= s_j_aux;

					-- hold the 8 byte measurement value from shifting
					s_hex_3axis_temp_measurements_val <=
						s_hex_3axis_temp_measurements_aux;

					-- stay in this state because auxiliary counting register
					-- \ref s_j_aux has not reached the maximum count of 8.
					s_stream_nx_state <= ST_WAIT_VALID;
				end if;

			when ST_DONE_CYCLE =>
				-- hold the byte count
				s_j_val <= s_j_aux;

				-- hold the 8 byte measurement value from shifting
				s_hex_3axis_temp_measurements_val <=
					s_hex_3axis_temp_measurements_aux;

				-- wait for GROUP VALID to deassert, and on this state
				-- transition, the synchronous state process will capture
				-- the 8 bytes of measurement value.
				if (s_acl2_rd_data_group_valid = '0') then
					s_stream_nx_state <= ST_WAIT_GROUP;
				else
					s_stream_nx_state <= ST_DONE_CYCLE;
				end if;

			when others => -- ST_WAIT_GROUP
				           -- preset the byte count to zero
				s_j_val <= 0;

				-- preset the 8 byte measurement value as zeros
				s_hex_3axis_temp_measurements_val <= (others => '0');

				-- wait for GROUP VALID to then wait for BYTE VALID
				if (s_acl2_rd_data_group_valid = '1') then
					s_stream_nx_state <= ST_WAIT_VALID;
				else
					s_stream_nx_state <= ST_WAIT_GROUP;
				end if;
		end case;
	end process p_stream_fsm_comb;

end architecture rtl;
--------------------------------------------------------------------------------
