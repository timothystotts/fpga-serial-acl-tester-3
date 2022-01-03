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
--------------------------------------------------------------------------------
-- \file fpga_serial_acl_tester_a7100_tb.vhdl
--
-- \brief Accelerometer control and reading, testbench.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--------------------------------------------------------------------------------
entity fpga_serial_acl_tester_a7100_tb is
end entity fpga_serial_acl_tester_a7100_tb;
--------------------------------------------------------------------------------
architecture simultation of fpga_serial_acl_tester_a7100_tb is
	component fpga_serial_acl_tester_a7100 is
		generic (
			parm_fast_simulation : integer := 0);
		port (
			CLK100MHZ         : in  std_logic;
			i_resetn          : in  std_logic;
			eo_pmod_acl2_sck  : out std_logic;
			eo_pmod_acl2_csn  : out std_logic;
			eo_pmod_acl2_copi : out std_logic;
			ei_pmod_acl2_cipo : in  std_logic;
			ei_pmod_acl2_int1 : in  std_logic;
			ei_pmod_acl2_int2 : in  std_logic;
			eo_led0_b         : out std_logic;
			eo_led1_b         : out std_logic;
			eo_led2_b         : out std_logic;
			eo_led3_b         : out std_logic;
			eo_led0_r         : out std_logic;
			eo_led1_r         : out std_logic;
			eo_led2_r         : out std_logic;
			eo_led3_r         : out std_logic;
			eo_led0_g         : out std_logic;
			eo_led1_g         : out std_logic;
			eo_led2_g         : out std_logic;
			eo_led3_g         : out std_logic;
			eo_led4           : out std_logic;
			eo_led5           : out std_logic;
			eo_led6           : out std_logic;
			eo_led7           : out std_logic;

			ei_sw0          : in  std_logic;
			ei_sw1          : in  std_logic;
			ei_sw2          : in  std_logic;
			ei_sw3          : in  std_logic;
			ei_btn0         : in  std_logic;
			ei_btn1         : in  std_logic;
			ei_btn2         : in  std_logic;
			ei_btn3         : in  std_logic;

			eo_pmod_cls_csn : out std_logic;
			eo_pmod_cls_sck : out std_logic;
			eo_pmod_cls_dq0 : out std_logic;
			ei_pmod_cls_dq1 : in  std_logic;
			eo_uart_tx      : out std_logic;
			ei_uart_rx      : in  std_logic;

			eo_ssd_pmod0 : out std_logic_vector(7 downto 0)
		);
	end component fpga_serial_acl_tester_a7100;

	constant c_clock_half_period : time := 5 ns;
	signal run_clock             : boolean;

	signal CLK100MHZ         : std_logic;
	signal si_resetn         : std_logic;
	signal so_pmod_acl2_sck  : std_logic;
	signal so_pmod_acl2_csn  : std_logic;
	signal so_pmod_acl2_copi : std_logic;
	signal si_pmod_acl2_cipo : std_logic;
	signal si_pmod_acl2_int1 : std_logic;
	signal si_pmod_acl2_int2 : std_logic;
	signal so_led0_b         : std_logic;
	signal so_led1_b         : std_logic;
	signal so_led2_b         : std_logic;
	signal so_led3_b         : std_logic;
	signal so_led0_r         : std_logic;
	signal so_led1_r         : std_logic;
	signal so_led2_r         : std_logic;
	signal so_led3_r         : std_logic;
	signal so_led0_g         : std_logic;
	signal so_led1_g         : std_logic;
	signal so_led2_g         : std_logic;
	signal so_led3_g         : std_logic;
	signal so_led4           : std_logic;
	signal so_led5           : std_logic;
	signal so_led6           : std_logic;
	signal so_led7           : std_logic;
	signal si_sw0            : std_logic;
	signal si_sw1            : std_logic;
	signal si_sw2            : std_logic;
	signal si_sw3            : std_logic;
	signal so_pmod_cls_csn   : std_logic;
	signal so_pmod_cls_sck   : std_logic;
	signal so_pmod_cls_dq0   : std_logic;
	signal si_pmod_cls_dq1   : std_logic;
	signal so_uart_tx        : std_logic;
	signal si_uart_rx        : std_logic;
	signal so_ssd_pmod0      : std_logic_vector(7 downto 0);

begin
	-- Unit Under Test: ACL2 Experiment
	uut_fpga_serial_acl_tester_a7100 : fpga_serial_acl_tester_a7100
		generic map (
			parm_fast_simulation => 1)
		port map (
			CLK100MHZ         => CLK100MHZ,
			i_resetn          => si_resetn,
			eo_pmod_acl2_sck  => so_pmod_acl2_sck,
			eo_pmod_acl2_csn  => so_pmod_acl2_csn,
			eo_pmod_acl2_copi => so_pmod_acl2_copi,
			ei_pmod_acl2_cipo => si_pmod_acl2_cipo,
			ei_pmod_acl2_int1 => si_pmod_acl2_int1,
			ei_pmod_acl2_int2 => si_pmod_acl2_int2,
			eo_led0_b         => so_led0_b,
			eo_led1_b         => so_led1_b,
			eo_led2_b         => so_led2_b,
			eo_led3_b         => so_led3_b,
			eo_led0_r         => so_led0_r,
			eo_led1_r         => so_led1_r,
			eo_led2_r         => so_led2_r,
			eo_led3_r         => so_led3_r,
			eo_led0_g         => so_led0_g,
			eo_led1_g         => so_led1_g,
			eo_led2_g         => so_led2_g,
			eo_led3_g         => so_led3_g,
			eo_led4           => so_led4,
			eo_led5           => so_led5,
			eo_led6           => so_led6,
			eo_led7           => so_led7,
			ei_sw0            => si_sw0,
			ei_sw1            => si_sw1,
			ei_sw2            => si_sw2,
			ei_sw3            => si_sw3,
			ei_btn0           => '0',
			ei_btn1           => '0',
			ei_btn2           => '0',
			ei_btn3           => '0',
			eo_pmod_cls_csn   => so_pmod_cls_csn,
			eo_pmod_cls_sck   => so_pmod_cls_sck,
			eo_pmod_cls_dq0   => so_pmod_cls_dq0,
			ei_pmod_cls_dq1   => si_pmod_cls_dq1,
			eo_uart_tx        => so_uart_tx,
			ei_uart_rx        => si_uart_rx,
			eo_ssd_pmod0      => so_ssd_pmod0
		);

	-- Simulated data response of UUT just to show visiual data on the waveform
	-- with no meaning other than if the Finite State Machines properly capture
	-- the received data from the bus and pass it on in-tact in the system
	-- interface.
	p_extend_seq_dat : process
		variable v_seq       : unsigned(7 downto 0) := x"00";
		variable v_cnt_msb   : natural range 0 to 7 := 0;
		variable v_track_cmd : std_logic            := '1';
	begin
		si_pmod_acl2_cipo <= 'Z';

		loop_forever : loop
			wait on so_pmod_acl2_csn, so_pmod_acl2_sck;

			-- on the falling edge of SCK, setup and hold a reply value on the
			-- SPI quad i/o to simulate answers back from the SPI Flash
			if so_pmod_acl2_sck'event and (so_pmod_acl2_sck = '0') then
				if (so_pmod_acl2_csn = '0') then
					wait for 10 ns;

					if (v_cnt_msb > 0) then
						v_cnt_msb := v_cnt_msb - 1;
						if (v_track_cmd = '0') then
							si_pmod_acl2_cipo <= std_logic(v_seq(v_cnt_msb));
						else
							si_pmod_acl2_cipo <= 'Z';
						end if;
					else
						v_cnt_msb         := 7;
						v_track_cmd       := '0';
						v_seq             := v_seq + unsigned'(x"01");
						si_pmod_acl2_cipo <= std_logic(v_seq(v_cnt_msb));
					end if;
				end if;
			-- on the event of s_sck 4x clock or change of chip select, test if
			-- necessary to High-Z the Quad I/O bus.
			elsif so_pmod_acl2_sck'event or so_pmod_acl2_csn'event then
				if (so_pmod_acl2_csn = '1') then
					wait for 10 ns;

					si_pmod_acl2_cipo <= 'Z';
					v_track_cmd       := '1';
					-- start one nibble before 0x00 as to simulate a working Flash
					-- chip response for a Quad I/O READ command reponse with a
					-- single SPI clock wait cycle after the 5 byte command.
					v_seq     := x"EF";
					v_cnt_msb := 7;
				end if;
			end if;
		end loop loop_forever;
	end process p_extend_seq_dat;


	-- This simulates INT1 toggling on and off, but does not connect it to the
	-- SPI reading of the Status register. The only purpose of this process
	-- \ref p_simulate_int1 is to provide a waveform viewing of the
	-- \ref i_start_measur_mode state machine running.
	p_simulate_int1 : process(CLK100MHZ)
		subtype t_counter1 is natural range 0 to 100_000_000 / 5_000;
		variable v_counter1 : t_counter1 := 0;
	begin
		if rising_edge(CLK100MHZ) then
			if (si_resetn = '0') then
				si_pmod_acl2_int1 <= '0';
				v_counter1        := 0;
			else
				if (v_counter1 < t_counter1'high) then
					v_counter1 := v_counter1 + 1;
				else
					v_counter1        := 0;
					si_pmod_acl2_int1 <= not si_pmod_acl2_int1;
				end if;
			end if;
		end if;
	end process p_simulate_int1;

	si_pmod_acl2_int2 <= '0';

	si_pmod_cls_dq1 <= '1';

	p_sw_emulation : process
	begin
		si_sw0 <= '1';
		si_sw1 <= '0';
		f1 : for iter in 0 to (100_000_000 * 45 / 1000) loop
			wait until (CLK100MHZ'event and (CLK100MHZ = '1'));
		end loop f1;

		si_sw0 <= '0';
		si_sw1 <= '0';
		f2 : for iter in 0 to (100_000_000 * 5 / 1000) loop
			wait until (CLK100MHZ'event and (CLK100MHZ = '1'));
		end loop f2;

		si_sw0 <= '0';
		si_sw1 <= '1';
		wait;
	end process p_sw_emulation;

	si_sw2 <= '0';
	si_sw3 <= '0';

	si_uart_rx <= '0';

	-- toggling clock until boolean run_clock goes false, then halt
	p_run_clock : process
	begin
		CLK100MHZ <= '0';
		wait for c_clock_half_period;

		forever_loop : while run_clock loop
			CLK100MHZ <= not CLK100MHZ;
			wait for c_clock_half_period;
		end loop forever_loop;

		wait;
	end process p_run_clock;

	-- reset signal that waits four clocks, asserts high four clocks, then
	-- deasserts
	p_run_rst : process
	begin
		run_clock <= true;

		si_resetn <= '1';

		wait_loop_1 : for iter in 1 to 100 loop
			wait until rising_edge(CLK100MHZ);
		end loop wait_loop_1;

		si_resetn <= '0';

		wait_loop_0 : for iter in 1 to 100 loop
			wait until rising_edge(CLK100MHZ);
		end loop wait_loop_0;

		si_resetn <= '1';

		wait_loop_run_b : for iter2 in 1 to 60 loop
			wait_loop_run_a : for iter in 1 to 100000000 loop
				wait until rising_edge(CLK100MHZ);
			end loop wait_loop_run_a;
		end loop wait_loop_run_b;

		run_clock <= false;
		wait;
	end process p_run_rst;

end architecture simultation;
--------------------------------------------------------------------------------
