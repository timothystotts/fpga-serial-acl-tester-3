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
-- \file fpga_serial_acl_tester_a7100.vhdl
--
-- \brief A FPGA top-level design with the PMOD ACL2 custom driver.
-- The target board is the Digilent Inc. Arty-A7-100 with a
-- Xilinx Artix-7 100T part.
-- This tester operates the ADXL362 in one of multiple possible operational
-- modes for Accelerometer data capture. The PMOD CLS is used to display raw
-- data for: X-Axis, Y-Axis, Z-Axis, Temperature. Color and basic LEDs
-- are used to display additional information, including Activity and Inactivity
-- motion detection.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.vcomponents.all;

library UNIMACRO;
use UNIMACRO.vcomponents.all;

library work;
use work.pmod_stand_spi_solo_pkg.all;
use work.led_pwm_driver_pkg.t_led_color_values;
--------------------------------------------------------------------------------
entity fpga_serial_acl_tester_a7100 is
	generic(
		-- Disable or enable fast FSM delays for simulation instead of impelementation.
		parm_fast_simulation : integer := 0);
	port(
		-- external clock and active-low reset
		CLK100MHZ : in std_logic;
		i_resetn  : in std_logic;
		-- PMOD ACL2 SPI bus 4-wire and two interrupt signals
		eo_pmod_acl2_sck  : out std_logic;
		eo_pmod_acl2_csn  : out std_logic;
		eo_pmod_acl2_copi : out std_logic;
		ei_pmod_acl2_cipo : in  std_logic;
		ei_pmod_acl2_int1 : in  std_logic;
		ei_pmod_acl2_int2 : in  std_logic;
		-- blue emitters of the multicolor LEDs
		eo_led0_b : out std_logic;
		eo_led1_b : out std_logic;
		eo_led2_b : out std_logic;
		eo_led3_b : out std_logic;
		-- red emitters of the multicolor LEDs
		eo_led0_r : out std_logic;
		eo_led1_r : out std_logic;
		eo_led2_r : out std_logic;
		eo_led3_r : out std_logic;
		-- green emitters of the multicolor LEDs
		eo_led0_g : out std_logic;
		eo_led1_g : out std_logic;
		eo_led2_g : out std_logic;
		eo_led3_g : out std_logic;
		-- green emitters of the basic LEDs
		eo_led4 : out std_logic;
		eo_led5 : out std_logic;
		eo_led6 : out std_logic;
		eo_led7 : out std_logic;
		-- four switches
		ei_sw0 : in std_logic;
		ei_sw1 : in std_logic;
		ei_sw2 : in std_logic;
		ei_sw3 : in std_logic;
		-- four buttons
		ei_btn0 : in std_logic;
		ei_btn1 : in std_logic;
		ei_btn2 : in std_logic;
		ei_btn3 : in std_logic;
		-- PMOD CLS SPI bus 4-wire
		eo_pmod_cls_csn : out std_logic;
		eo_pmod_cls_sck : out std_logic;
		eo_pmod_cls_dq0 : out std_logic;
		ei_pmod_cls_dq1 : in  std_logic;
		-- Arty A7-100T UART TX and RX signals
		eo_uart_tx : out std_logic;
		ei_uart_rx : in  std_logic;
		-- PMOD SSD direct GPIO
		eo_ssd_pmod0 : out std_logic_vector(7 downto 0)
	);
end entity fpga_serial_acl_tester_a7100;
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
architecture rtl of fpga_serial_acl_tester_a7100 is

	-- Main clock frequency in Hz
	constant c_FCLK : natural := 20_000_000;

	-- MMCM and System Reset signals
	signal s_mmcm_locked : std_logic;
	signal s_clk_20mhz   : std_logic;
	signal s_rst_20mhz   : std_logic;
	signal s_clk_7_37mhz : std_logic;
	signal s_rst_7_37mhz : std_logic;
	signal s_ce_2_5mhz   : std_logic;

	-- Definitions of the Standard SPI driver to pass to the ACL2 and CLS drivers
	constant c_stand_spi_tx_fifo_count_bits : natural := 5;
	constant c_stand_spi_rx_fifo_count_bits : natural := 5;
	constant c_stand_spi_wait_count_bits    : natural := 2;

	-- Tri-state connectivity with the PMOD ACL2.
	signal so_pmod_acl2_sck_o  : std_logic;
	signal so_pmod_acl2_sck_t  : std_logic;
	signal so_pmod_acl2_csn_o  : std_logic;
	signal so_pmod_acl2_csn_t  : std_logic;
	signal so_pmod_acl2_copi_o : std_logic;
	signal so_pmod_acl2_copi_t : std_logic;

	-- Data and indications to be displayed on the LEDs and CLS.
	signal s_acl2_reg_status                      : t_pmod_acl2_reg_1;
	signal s_acl2_reg_status_activity_stretched   : std_logic;
	signal s_acl2_reg_status_inactivity_stretched : std_logic;
	signal s_hex_3axis_temp_measurements_final    : t_pmod_acl2_reg_8;
	signal s_hex_3axis_temp_measurements_valid    : std_logic;
	signal s_hex_3axis_temp_measurements_display  : t_pmod_acl2_reg_8;
	signal s_reading_inactive                     : std_logic;

	-- Command to Operating Mode signals for the Tester FSM.
	signal s_acl2_command_ready         : std_logic;
	signal s_acl2_cmd_init_measur_mode  : std_logic;
	signal s_acl2_cmd_start_measur_mode : std_logic;
	signal s_acl2_cmd_init_linked_mode  : std_logic;
	signal s_acl2_cmd_start_linked_mode : std_logic;
	signal s_acl2_cmd_soft_reset_acl2   : std_logic;

	-- Tester FSM general outputs that translate to LED color display.
	signal s_active_init_display : std_logic;
	signal s_active_run_display  : std_logic;
	signal s_mode_is_measur      : std_logic;
	signal s_mode_is_linked      : std_logic;

	-- switch inputs debounced
	signal si_switches : std_logic_vector(3 downto 0);
	signal s_sw_deb    : std_logic_vector(3 downto 0);

	-- button inputs debounced
	signal si_buttons : std_logic_vector(3 downto 0);
	signal s_btn_deb  : std_logic_vector(3 downto 0);

	-- Signals for controlling the PMOD CLS custom driver.
	signal s_cls_command_ready    : std_logic;
	signal s_cls_wr_clear_display : std_logic;
	signal s_cls_wr_text_line1    : std_logic;
	signal s_cls_wr_text_line2    : std_logic;
	signal s_cls_txt_ascii_line1  : t_pmod_cls_ascii_line_16;
	signal s_cls_txt_ascii_line2  : t_pmod_cls_ascii_line_16;
	signal s_cls_feed_is_idle     : std_logic;

	-- Signals for text and data ASCII lines
	signal s_adxl_dat_ascii_line1 : t_pmod_cls_ascii_line_16;
	signal s_adxl_dat_ascii_line2 : t_pmod_cls_ascii_line_16;
	signal s_adxl_txt_ascii_line1 : t_pmod_cls_ascii_line_16;
	signal s_adxl_txt_ascii_line2 : t_pmod_cls_ascii_line_16;

	-- Signals for inferring tri-state buffer for CLS SPI bus outputs.
	signal so_pmod_cls_sck_o  : std_logic;
	signal so_pmod_cls_sck_t  : std_logic;
	signal so_pmod_cls_csn_o  : std_logic;
	signal so_pmod_cls_csn_t  : std_logic;
	signal so_pmod_cls_copi_o : std_logic;
	signal so_pmod_cls_copi_t : std_logic;

	-- Extra MMCM signals for full port map to the MMCM primative, where
	-- these signals will remain disconnected.
	signal s_clk_ignore_clk0b     : std_logic;
	signal s_clk_ignore_clk1b     : std_logic;
	signal s_clk_ignore_clk2      : std_logic;
	signal s_clk_ignore_clk2b     : std_logic;
	signal s_clk_ignore_clk3      : std_logic;
	signal s_clk_ignore_clk3b     : std_logic;
	signal s_clk_ignore_clk4      : std_logic;
	signal s_clk_ignore_clk5      : std_logic;
	signal s_clk_ignore_clk6      : std_logic;
	signal s_clk_ignore_clkfboutb : std_logic;
	-- Extra MMCM signals for full port map to the MMCM primative, where
	-- these signals are connected.
	signal s_clk_clkfbout         : std_logic;
	signal s_clk_pwrdwn           : std_logic;
	signal s_clk_resetin          : std_logic;

	-- Color palette signals to connect \ref led_palette_pulser to
	-- \ref led_pwm_driver .
	signal s_color_led_red_value   : t_led_color_values(3 downto 0);
	signal s_color_led_green_value : t_led_color_values(3 downto 0);
	signal s_color_led_blue_value  : t_led_color_values(3 downto 0);
	signal s_basic_led_lumin_value : t_led_color_values(3 downto 0);

	-- UART TX signals to connect \ref uart_tx_only and \ref uart_tx_feed .
	signal s_uart_dat_ascii_line : std_logic_vector((34*8-1) downto 0);
	signal s_uart_tx_go          : std_logic;
	signal s_uart_txdata         : std_logic_vector(7 downto 0);
	signal s_uart_txvalid        : std_logic;
	signal s_uart_txready        : std_logic;

	-- Values for display on the Pmod SSD
	signal s_thresh_value0 : std_logic_vector(3 downto 0);
	signal s_thresh_value1 : std_logic_vector(3 downto 0);
begin

	s_clk_pwrdwn  <= '0';
	s_clk_resetin <= not i_resetn;

	-- MMCME2_BASE: Base Mixed Mode Clock Manager
	--              Artix-7
	-- Xilinx HDL Language Template, version 2019.1

	MMCME2_BASE_inst : MMCME2_BASE
		generic map (
			BANDWIDTH       => "OPTIMIZED", -- Jitter programming (OPTIMIZED, HIGH, LOW)
			CLKFBOUT_MULT_F => 36.125,      -- Multiply value for all CLKOUT (2.000-64.000).
			CLKFBOUT_PHASE  => 0.0,         -- Phase offset in degrees of CLKFB (-360.000-360.000).
			CLKIN1_PERIOD   => 10.0,        -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
			                                -- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
			CLKOUT1_DIVIDE   => 98,
			CLKOUT2_DIVIDE   => 1,
			CLKOUT3_DIVIDE   => 1,
			CLKOUT4_DIVIDE   => 1,
			CLKOUT5_DIVIDE   => 1,
			CLKOUT6_DIVIDE   => 1,
			CLKOUT0_DIVIDE_F => 36.125, -- Divide amount for CLKOUT0 (1.000-128.000).
			                            -- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
			CLKOUT0_DUTY_CYCLE => 0.5,
			CLKOUT1_DUTY_CYCLE => 0.5,
			CLKOUT2_DUTY_CYCLE => 0.5,
			CLKOUT3_DUTY_CYCLE => 0.5,
			CLKOUT4_DUTY_CYCLE => 0.5,
			CLKOUT5_DUTY_CYCLE => 0.5,
			CLKOUT6_DUTY_CYCLE => 0.5,
			-- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
			CLKOUT0_PHASE   => 0.0,
			CLKOUT1_PHASE   => 0.0,
			CLKOUT2_PHASE   => 0.0,
			CLKOUT3_PHASE   => 0.0,
			CLKOUT4_PHASE   => 0.0,
			CLKOUT5_PHASE   => 0.0,
			CLKOUT6_PHASE   => 0.0,
			CLKOUT4_CASCADE => FALSE, -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
			DIVCLK_DIVIDE   => 5,     -- Master division value (1-106)
			REF_JITTER1     => 0.010, -- Reference input jitter in UI (0.000-0.999).
			STARTUP_WAIT    => FALSE  -- Delays DONE until MMCM is locked (FALSE, TRUE)
		)
		port map (
			-- Clock Outputs: 1-bit (each) output: User configurable clock outputs
			CLKOUT0  => s_clk_20mhz,             -- 1-bit output: CLKOUT0
			CLKOUT0B => s_clk_ignore_clk0b,      -- 1-bit output: Inverted CLKOUT0
			CLKOUT1  => s_clk_7_37mhz,           -- 1-bit output: CLKOUT1
			CLKOUT1B => s_clk_ignore_clk1b,      -- 1-bit output: Inverted CLKOUT1
			CLKOUT2  => s_clk_ignore_clk2,       -- 1-bit output: CLKOUT2
			CLKOUT2B => s_clk_ignore_clk2b,      -- 1-bit output: Inverted CLKOUT2
			CLKOUT3  => s_clk_ignore_clk3,       -- 1-bit output: CLKOUT3
			CLKOUT3B => s_clk_ignore_clk3b,      -- 1-bit output: Inverted CLKOUT3
			CLKOUT4  => s_clk_ignore_clk4,       -- 1-bit output: CLKOUT4
			CLKOUT5  => s_clk_ignore_clk5,       -- 1-bit output: CLKOUT5
			CLKOUT6  => s_clk_ignore_clk6,       -- 1-bit output: CLKOUT6
			                                     -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
			CLKFBOUT  => s_clk_clkfbout,         -- 1-bit output: Feedback clock
			CLKFBOUTB => s_clk_ignore_clkfboutb, -- 1-bit output: Inverted CLKFBOUT
			                                     -- Status Ports: 1-bit (each) output: MMCM status ports
			LOCKED => s_mmcm_locked,             -- 1-bit output: LOCK
			                                     -- Clock Inputs: 1-bit (each) input: Clock input
			CLKIN1 => CLK100MHZ,                 -- 1-bit input: Clock
			                                     -- Control Ports: 1-bit (each) input: MMCM control ports
			PWRDWN => s_clk_pwrdwn,              -- 1-bit input: Power-down
			RST    => s_clk_resetin,             -- 1-bit input: Reset
			                                     -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
			CLKFBIN => s_clk_clkfbout            -- 1-bit input: Feedback clock
		);
	-- End of MMCME2_BASE_inst instantiation

	-- Reset Synchronization for 20 MHz clock
	u_reset_sync_20mhz : entity work.arty_reset_synchronizer(rtl)
		port map(
			i_clk_mhz     => s_clk_20mhz,
			i_rstn_global => i_resetn,
			o_rst_mhz     => s_rst_20mhz
		);

	-- Reset Synchronization for 20 MHz clock
	u_reset_sync_7_37mhz : entity work.arty_reset_synchronizer(rtl)
		port map(
			i_clk_mhz     => s_clk_7_37mhz,
			i_rstn_global => i_resetn,
			o_rst_mhz     => s_rst_7_37mhz
		);

	-- 4x spi clock enable divider for PMOD CLS SCK output. No
	-- generated clock constraint. The 20 MHz clock is divided
	-- down to 2.5 MHz; and later divided down to 625 KHz on
	-- the PMOD CLS bus.
	u_2_5mhz_ce_divider : entity work.clock_enable_divider(rtl)
		generic map(
			par_ce_divisor => 8
		)
		port map(
			o_ce_div  => s_ce_2_5mhz,
			i_clk_mhz => s_clk_20mhz,
			i_rst_mhz => s_rst_20mhz,
			i_ce_mhz  => '1'
		);

	-- Synchronize and debounce the four input switches on the Arty A7 to be
	-- debounced and exclusive of each other (ignored if more than one
	-- selected at the same time).
	si_switches <= ei_sw3 & ei_sw2 & ei_sw1 & ei_sw0;

	u_switches_deb_0123 : entity work.multi_input_debounce(moore_fsm)
		generic map(
			FCLK => c_FCLK
		)
		port map(
			i_clk_mhz  => s_clk_20mhz,
			i_rst_mhz  => s_rst_20mhz,
			ei_buttons => si_switches,
			o_btns_deb => s_sw_deb
		);

	-- Synchronize and debounce the four input buttons on the Arty A7 to be
	-- debounced and exclusive of each other (ignored if more than one
	-- selected at the same time).
	si_buttons <= ei_btn3 & ei_btn2 & ei_btn1 & ei_btn0;

	u_buttons_deb_0123 : entity work.multi_input_debounce(moore_fsm)
		generic map(
			FCLK => c_FCLK
		)
		port map(
			i_clk_mhz  => s_clk_20mhz,
			i_rst_mhz  => s_rst_20mhz,
			ei_buttons => si_buttons,
			o_btns_deb => s_btn_deb
		);

	-- LED PWM driver for color-mixed LED driving with variable intensity.
	u_led_pwm_driver : entity work.led_pwm_driver(rtl)
		generic map(
			parm_color_led_count         => 4,
			parm_basic_led_count         => 4,
			parm_FCLK                    => c_FCLK,
			parm_pwm_period_milliseconds => 10
		)
		port map(
			i_clk                   => s_clk_20mhz,
			i_srst                  => s_rst_20mhz,
			i_color_led_red_value   => s_color_led_red_value,
			i_color_led_green_value => s_color_led_green_value,
			i_color_led_blue_value  => s_color_led_blue_value,
			i_basic_led_lumin_value => s_basic_led_lumin_value,
			eo_color_leds_r(3)      => eo_led3_r,
			eo_color_leds_r(2)      => eo_led2_r,
			eo_color_leds_r(1)      => eo_led1_r,
			eo_color_leds_r(0)      => eo_led0_r,
			eo_color_leds_g(3)      => eo_led3_g,
			eo_color_leds_g(2)      => eo_led2_g,
			eo_color_leds_g(1)      => eo_led1_g,
			eo_color_leds_g(0)      => eo_led0_g,
			eo_color_leds_b(3)      => eo_led3_b,
			eo_color_leds_b(2)      => eo_led2_b,
			eo_color_leds_b(1)      => eo_led1_b,
			eo_color_leds_b(0)      => eo_led0_b,
			eo_basic_leds_l(3)      => eo_led7,
			eo_basic_leds_l(2)      => eo_led6,
			eo_basic_leds_l(1)      => eo_led5,
			eo_basic_leds_l(0)      => eo_led4
		);

	-- LED palette pulser to manage the display of the LEDs
	u_led_palette_pulser : entity work.led_palette_pulser(rtl)
		generic map (
			parm_color_led_count        => 4,
			parm_basic_led_count        => 4,
			parm_FCLK                   => c_FCLK,
			parm_adjustments_per_second => 85
		)
		port map (
			i_clk                       => s_clk_20mhz,
			i_srst                      => s_rst_20mhz,
			o_color_led_red_value       => s_color_led_red_value,
			o_color_led_green_value     => s_color_led_green_value,
			o_color_led_blue_value      => s_color_led_blue_value,
			o_basic_led_lumin_value     => s_basic_led_lumin_value,
			i_active_init_display       => s_active_init_display,
			i_active_run_display        => s_active_run_display,
			i_mode_is_measur_aux        => s_mode_is_measur,
			i_mode_is_linked_aux        => s_mode_is_linked,
			i_acl2_activity_stretched   => s_acl2_reg_status_activity_stretched,
			i_acl2_inactivity_stretched => s_acl2_reg_status_inactivity_stretched,
			i_acl2_awake_status         => s_acl2_reg_status(6),
			i_sw0_selected              => s_sw_deb(0),
			i_sw1_selected              => s_sw_deb(1)
		);

	-- Provide possible tri-state for later design revision for the PMOD ACL2 SPI
	-- output ports.
	eo_pmod_acl2_sck  <= so_pmod_acl2_sck_o  when so_pmod_acl2_sck_t = '0' else 'Z';
	eo_pmod_acl2_csn  <= so_pmod_acl2_csn_o  when so_pmod_acl2_csn_t = '0' else 'Z';
	eo_pmod_acl2_copi <= so_pmod_acl2_copi_o when so_pmod_acl2_copi_t = '0' else 'Z';

	-- PMOD ACL2 Custom Driver instance.
	u_pmod_acl2_custom_driver : entity work.pmod_acl2_custom_driver(rtl)
		generic map (
			parm_fast_simulation   => parm_fast_simulation,
			parm_FCLK              => c_FCLK,
			parm_ext_spi_clk_ratio => 4
		)
		port map (
			i_clk_20mhz             => s_clk_20mhz,
			i_rst_20mhz             => s_rst_20mhz,
			eo_sck_t                => so_pmod_acl2_sck_t,
			eo_sck_o                => so_pmod_acl2_sck_o,
			eo_csn_t                => so_pmod_acl2_csn_t,
			eo_csn_o                => so_pmod_acl2_csn_o,
			eo_copi_t               => so_pmod_acl2_copi_t,
			eo_copi_o               => so_pmod_acl2_copi_o,
			ei_cipo                 => ei_pmod_acl2_cipo,
			ei_int1                 => ei_pmod_acl2_int1,
			ei_int2                 => ei_pmod_acl2_int2,
			o_command_ready         => s_acl2_command_ready,
			i_cmd_init_linked_mode  => s_acl2_cmd_init_linked_mode,
			i_cmd_start_linked_mode => s_acl2_cmd_start_linked_mode,
			i_cmd_init_measur_mode  => s_acl2_cmd_init_measur_mode,
			i_cmd_start_measur_mode => s_acl2_cmd_start_measur_mode,
			i_cmd_soft_reset_acl2   => s_acl2_cmd_soft_reset_acl2,
			o_data_3axis_temp       => s_hex_3axis_temp_measurements_final,
			o_data_valid            => s_hex_3axis_temp_measurements_valid,
			o_reg_status            => s_acl2_reg_status,
			i_btn_deb               => s_btn_deb(1 downto 0),
			o_enum_active           => s_thresh_value1,
			o_enum_inactive         => s_thresh_value0
		);

	-- Tester FSM to operate the states of the Pmod ACL2 based on switch input
	u_acl_tester_fsm : entity work.acl_tester_fsm(rtl)
		port map (
			i_clk_20mhz                 => s_clk_20mhz,
			i_rst_20mhz                 => s_rst_20mhz,
			i_acl_command_ready         => s_acl2_command_ready,
			i_switches_debounced        => s_sw_deb,
			o_reading_inactive          => s_reading_inactive,
			o_active_init_display       => s_active_init_display,
			o_active_run_display        => s_active_run_display,
			o_mode_is_measur            => s_mode_is_measur,
			o_mode_is_linked            => s_mode_is_linked,
			o_acl_cmd_init_measur_mode  => s_acl2_cmd_init_measur_mode,
			o_acl_cmd_start_measur_mode => s_acl2_cmd_start_measur_mode,
			o_acl_cmd_init_linked_mode  => s_acl2_cmd_init_linked_mode,
			o_acl_cmd_start_linked_mode => s_acl2_cmd_start_linked_mode,
			o_acl_cmd_soft_reset        => s_acl2_cmd_soft_reset_acl2
		);

	-- Capture the latest measurement value on VALID pulse and when the display is
	-- idling in preparation of the next value to be displayed. When the display
	-- stops idling, then hold the value for display so that the display does not
	-- have its textual inputs changing while running the display update. This
	-- value capture also holds for the UART TX output of the values.
	p_hold_measurements : process(s_clk_20mhz)
	begin
		if rising_edge(s_clk_20mhz) then
			if (s_rst_20mhz = '1') then
				s_hex_3axis_temp_measurements_display <= (others => '0');
			else
				if ((s_hex_3axis_temp_measurements_valid = '1') and (s_cls_feed_is_idle = '1')) then

					s_hex_3axis_temp_measurements_display <= s_hex_3axis_temp_measurements_final;
				end if;
			end if;
		end if;
	end process p_hold_measurements;

	-- Stretch the Activity indication so it can be displayed as color LED 2.
	u_pulse_stretcher_activity : entity work.pulse_stretcher_synch(moore_fsm_timed)
		generic map(
			par_T_stretch_count => c_FCLK)
		port map(
			o_y   => s_acl2_reg_status_activity_stretched,
			i_clk => s_clk_20mhz,
			i_rst => s_rst_20mhz,
			i_x   => s_acl2_reg_status(4));

	-- Stretch the Inactivity indication so it can be displayed as color LED 3.
	u_pulse_stretcher_inactivity : entity work.pulse_stretcher_synch(moore_fsm_timed)
		generic map(
			par_T_stretch_count => c_FCLK)
		port map(
			o_y   => s_acl2_reg_status_inactivity_stretched,
			i_clk => s_clk_20mhz,
			i_rst => s_rst_20mhz,
			i_x   => s_acl2_reg_status(5));

	-- Tri-state outputs of PMOD CLS custom driver.
	eo_pmod_cls_sck <= so_pmod_cls_sck_o  when so_pmod_cls_sck_t = '0' else 'Z';
	eo_pmod_cls_csn <= so_pmod_cls_csn_o  when so_pmod_cls_csn_t = '0' else 'Z';
	eo_pmod_cls_dq0 <= so_pmod_cls_copi_o when so_pmod_cls_copi_t = '0' else 'Z';

	-- Instance of the PMOD CLS driver for 16x2 character LCD display for purposes
	-- of an output display.
	u_pmod_cls_custom_driver : entity work.pmod_cls_custom_driver(rtl)
		generic map (
			parm_fast_simulation   => parm_fast_simulation,
			parm_FCLK              => c_FCLK,
			parm_FCLK_ce           => 2_500_000,
			parm_ext_spi_clk_ratio => 32
		)
		port map (
			i_clk_20mhz            => s_clk_20mhz,
			i_rst_20mhz            => s_rst_20mhz,
			i_ce_2_5mhz            => s_ce_2_5mhz,
			eo_sck_t               => so_pmod_cls_sck_t,
			eo_sck_o               => so_pmod_cls_sck_o,
			eo_csn_t               => so_pmod_cls_csn_t,
			eo_csn_o               => so_pmod_cls_csn_o,
			eo_copi_t              => so_pmod_cls_copi_t,
			eo_copi_o              => so_pmod_cls_copi_o,
			ei_cipo                => ei_pmod_cls_dq1,
			o_command_ready        => s_cls_command_ready,
			i_cmd_wr_clear_display => s_cls_wr_clear_display,
			i_cmd_wr_text_line1    => s_cls_wr_text_line1,
			i_cmd_wr_text_line2    => s_cls_wr_text_line2,
			i_dat_ascii_line1      => s_cls_txt_ascii_line1,
			i_dat_ascii_line2      => s_cls_txt_ascii_line2
		);

	-- Select the text to display on the Pmod CLS based om whether button 3
	-- is or is not depressed.
	p_reg_cls_line : process(s_clk_20mhz)
	begin
		if rising_edge(s_clk_20mhz) then
			if (s_btn_deb = "1000") then
				s_cls_txt_ascii_line1 <= s_adxl_dat_ascii_line1;
				s_cls_txt_ascii_line2 <= s_adxl_dat_ascii_line2;
			else
				s_cls_txt_ascii_line1 <= s_adxl_txt_ascii_line1;
				s_cls_txt_ascii_line2 <= s_adxl_txt_ascii_line2;
			end if;
		end if;
	end process p_reg_cls_line;

	-- LCD Update FSM
	u_lcd_text_feed : entity work.lcd_text_feed(rtl)
		generic map (
			parm_fast_simulation => parm_fast_simulation
		)
		port map (
			i_clk_20mhz            => s_clk_20mhz,
			i_rst_20mhz            => s_rst_20mhz,
			i_ce_2_5mhz            => s_ce_2_5mhz,
			i_lcd_command_ready    => s_cls_command_ready,
			o_lcd_wr_clear_display => s_cls_wr_clear_display,
			o_lcd_wr_text_line1    => s_cls_wr_text_line1,
			o_lcd_wr_text_line2    => s_cls_wr_text_line2,
			o_lcd_feed_is_idle     => s_cls_feed_is_idle
		);

	-- Measurement Readings to ASCII conversion
	u_adxl362_readings_to_ascii : entity work.adxl362_readings_to_ascii
		port map (
			i_3axis_temp       => s_hex_3axis_temp_measurements_display,
			i_reading_inactive => s_reading_inactive,
			o_dat_ascii_line1  => s_adxl_dat_ascii_line1,
			o_dat_ascii_line2  => s_adxl_dat_ascii_line2,
			o_txt_ascii_line1  => s_adxl_txt_ascii_line1,
			o_txt_ascii_line2  => s_adxl_txt_ascii_line2
		);

	-- TX ONLY UART function to print the two lines of the PMOD CLS output as a
	-- single line on the dumb terminal, at the same rate as the PMOD CLS updates.
	-- Assembly of UART text line.

	-- Select the text to display on the UART Terminal based om whether button 2
	-- is or is not depressed.
	p_reg_uart_line : process(s_clk_20mhz)
	begin
		if rising_edge(s_clk_20mhz) then
			if (s_btn_deb = "0100") then
				s_uart_dat_ascii_line <=
					(s_adxl_txt_ascii_line1 & s_adxl_txt_ascii_line2 & x"0D" & x"0A");
			else
				s_uart_dat_ascii_line <=
					(s_adxl_dat_ascii_line1 & s_adxl_dat_ascii_line2 & x"0D" & x"0A");
			end if;
		end if;
	end process p_reg_uart_line;

	s_uart_tx_go <= s_cls_wr_clear_display;

	u_uart_tx_only : entity work.uart_tx_only(moore_fsm_recursive)
		generic map (
			parm_BAUD => 115200,
			parm_ascii_line_length => 34,
			parm_almost_full_thresh => "111" & x"dd"
		)
		port map (
			i_clk_20mhz   => s_clk_20mhz,
			i_rst_20mhz   => s_rst_20mhz,
			i_clk_7_37mhz => s_clk_7_37mhz,
			i_rst_7_37mhz => s_rst_7_37mhz,
			eo_uart_tx    => eo_uart_tx,
			i_tx_data     => s_uart_txdata,
			i_tx_valid    => s_uart_txvalid,
			o_tx_ready    => s_uart_txready
		);

	u_uart_tx_feed : entity work.uart_tx_feed(rtl)
		generic map(
			parm_ascii_line_length => 34
		)
		port map(
			i_clk_20mhz      => s_clk_20mhz,
			i_rst_20mhz      => s_rst_20mhz,
			o_tx_data        => s_uart_txdata,
			o_tx_valid       => s_uart_txvalid,
			i_tx_ready       => s_uart_txready,
			i_tx_go          => s_uart_tx_go,
			i_dat_ascii_line => s_uart_dat_ascii_line
		);

	-- A single PMOD SSD, two digit seven segment display
	u_one_pmod_ssd_display : entity work.one_pmod_ssd_display(rtl)
		port map (
			i_clk_20mhz => s_clk_20mhz,
			i_rst_20mhz => s_rst_20mhz,
			i_value0    => s_thresh_value0,
			i_value1    => s_thresh_value1,
			o_ssd_pmod0 => eo_ssd_pmod0
		);

end architecture rtl;
--------------------------------------------------------------------------------
