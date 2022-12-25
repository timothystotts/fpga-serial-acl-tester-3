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
-- \file acl_tester_fsm.vhdl
--
-- \brief A simple FSM to control the execution of the ADXL362 accelerometer
-- testing.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--------------------------------------------------------------------------------
entity acl_tester_fsm is
	port(
		i_clk_20mhz : in std_logic;
		i_rst_20mhz : in std_logic;

		i_acl_command_ready  : in std_logic;
		i_switches_debounced : in std_logic_vector(3 downto 0);

		o_reading_inactive          : out std_logic;
		o_active_init_display       : out std_logic;
		o_active_run_display        : out std_logic;
		o_mode_is_measur            : out std_logic;
		o_mode_is_linked            : out std_logic;
		o_acl_cmd_init_measur_mode  : out std_logic;
		o_acl_cmd_start_measur_mode : out std_logic;
		o_acl_cmd_init_linked_mode  : out std_logic;
		o_acl_cmd_start_linked_mode : out std_logic;
		o_acl_cmd_soft_reset        : out std_logic
	);
end entity acl_tester_fsm;
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
architecture rtl of acl_tester_fsm is
	-- Tester FSM state declarations
	type t_tester_state is (ST_0, ST_1, ST_2, ST_3, ST_4, ST_5, ST_6, ST_7,
			ST_8, ST_9, ST_A, ST_B);

	signal s_tester_pr_state : t_tester_state := ST_0;
	signal s_tester_nx_state : t_tester_state := ST_0;

	-- Tester FSM auxiliary registers that translate to LED color display.
	signal s_mode_is_measur_val : std_logic;
	signal s_mode_is_measur_aux : std_logic;
	signal s_mode_is_linked_val : std_logic;
	signal s_mode_is_linked_aux : std_logic;
begin
	-- State auxiliary outputs
	o_mode_is_linked <= s_mode_is_linked_aux;
	o_mode_is_measur <= s_mode_is_measur_aux;

	-- The top-level Tester FSM State Transition register on the system clock,
	-- for state and auxiliary of the FSM that sends operation mode commands to
	-- the PMOD ACL2 custom driver.
	p_tester_fsm_state_aux : process(i_clk_20mhz)
	begin
		if rising_edge(i_clk_20mhz) then
			if (i_rst_20mhz = '1') then
				s_tester_pr_state <= ST_0;

				s_mode_is_measur_aux <= '0';
				s_mode_is_linked_aux <= '0';
			else
				s_tester_pr_state <= s_tester_nx_state;

				s_mode_is_measur_aux <= s_mode_is_measur_val;
				s_mode_is_linked_aux <= s_mode_is_linked_val;
			end if;
		end if;
	end process p_tester_fsm_state_aux;

	-- Tester FSM Combinatorial logic for initializing and starting PMOD ACL2
	-- according to the position of Switch 0 and the position of Switch 1. If
	-- Switch 0 and Not Switch 1, then Mode Measurement is executed. If Switch 1
	-- and Not Switch 0, then Mode Linked is executed.
	p_tester_fsm_comb : process(s_tester_pr_state, i_acl_command_ready,
			i_switches_debounced,
			s_mode_is_measur_aux, s_mode_is_linked_aux)
	begin
		-- default the current PR state to not issue any of the five possible commands
		o_acl_cmd_init_measur_mode  <= '0';
		o_acl_cmd_init_linked_mode  <= '0';
		o_acl_cmd_start_measur_mode <= '0';
		o_acl_cmd_start_linked_mode <= '0';
		o_acl_cmd_soft_reset        <= '0';
		o_reading_inactive          <= '0';

		case (s_tester_pr_state) is
			when ST_1 => -- Step one to command initialize the ACL2 to measurement mode
				o_acl_cmd_init_measur_mode <= '1';
				o_active_init_display      <= '1';
				o_active_run_display       <= '0';
				s_mode_is_measur_val       <= '1';
				s_mode_is_linked_val       <= '0';

				if (i_acl_command_ready = '1') then
					s_tester_nx_state <= ST_1;
				else
					s_tester_nx_state <= ST_2;
				end if;

			when ST_2 => -- Step two to wait for ACL2 to initialize its MM initialization
				o_active_init_display <= '1';
				o_active_run_display  <= '0';
				s_mode_is_measur_val  <= s_mode_is_measur_aux;
				s_mode_is_linked_val  <= s_mode_is_linked_aux;

				if (i_acl_command_ready = '0') then
					s_tester_nx_state <= ST_2;
				else
					s_tester_nx_state <= ST_3;
				end if;

			when ST_3 => -- Step three to command start the ACL2 to measurement mode
				o_acl_cmd_start_measur_mode <= '1';
				o_active_init_display       <= '1';
				o_active_run_display        <= '0';
				s_mode_is_measur_val        <= s_mode_is_measur_aux;
				s_mode_is_linked_val        <= s_mode_is_linked_aux;

				if (i_acl_command_ready = '1') then
					s_tester_nx_state <= ST_3;
				else
					s_tester_nx_state <= ST_4;
				end if;

			when ST_4 => -- Step four to stop issuing ACL2 commands and transition to IDLE
				         -- (place holder for other steps)
				o_active_init_display <= '1';
				o_active_run_display  <= '0';
				s_mode_is_measur_val  <= s_mode_is_measur_aux;
				s_mode_is_linked_val  <= s_mode_is_linked_aux;

				s_tester_nx_state <= ST_9;

			when ST_5 => -- Step one to command initialize the ACL2 to linked mode
				o_acl_cmd_init_linked_mode <= '1';
				o_active_init_display      <= '1';
				o_active_run_display       <= '0';
				s_mode_is_measur_val       <= '0';
				s_mode_is_linked_val       <= '1';

				if (i_acl_command_ready = '1') then
					s_tester_nx_state <= ST_5;
				else
					s_tester_nx_state <= ST_6;
				end if;

			when ST_6 => -- Step two to wait for ACL2 to start its LM initialization
				o_active_init_display <= '1';
				o_active_run_display  <= '0';
				s_mode_is_measur_val  <= s_mode_is_measur_aux;
				s_mode_is_linked_val  <= s_mode_is_linked_aux;

				if (i_acl_command_ready = '0') then
					s_tester_nx_state <= ST_6;
				else
					s_tester_nx_state <= ST_7;
				end if;

			when ST_7 => -- Step three to command start the ACL2 to linked mode
				o_acl_cmd_start_linked_mode <= '1';
				o_active_init_display       <= '1';
				o_active_run_display        <= '0';
				s_mode_is_measur_val        <= s_mode_is_measur_aux;
				s_mode_is_linked_val        <= s_mode_is_linked_aux;

				if (i_acl_command_ready = '1') then
					s_tester_nx_state <= ST_7;
				else
					s_tester_nx_state <= ST_8;
				end if;

			when ST_8 => -- Step four to stop issuing commands and transition to IDLE
				         -- (place holder for other steps)
				o_active_init_display <= '1';
				o_active_run_display  <= '0';
				s_mode_is_measur_val  <= s_mode_is_measur_aux;
				s_mode_is_linked_val  <= s_mode_is_linked_aux;

				s_tester_nx_state <= ST_9;

			when ST_9 => -- State nine is RUNNING IDLE and waits for switches 0,1
				         -- to enter a non-exclusive state to then transition
				         -- to State A which in turn will reset the PMOD ACL2 and wait
				         -- for an exclusive command on the switches 0,1.
				o_active_init_display <= '0';
				o_active_run_display  <= '1';
				s_mode_is_measur_val  <= s_mode_is_measur_aux;
				s_mode_is_linked_val  <= s_mode_is_linked_aux;

				if (i_switches_debounced = "0000") then -- no solitary switch is ON
					s_tester_nx_state <= ST_A;
				else
					s_tester_nx_state <= ST_9;
				end if;

			when ST_A => -- Step A to issue the Soft Reset command to the PMOD ACL2
				         -- Then transition to Step Zero for INIT IDLE and waiting
				         -- for exclusive switch position.
				o_acl_cmd_soft_reset  <= '1'; -- acts as a level interrupt instead of command
				o_active_init_display <= '0';
				o_active_run_display  <= '0';
				s_mode_is_measur_val  <= '0';
				s_mode_is_linked_val  <= '0';

				if (i_acl_command_ready = '1') then
					s_tester_nx_state <= ST_0;
				else
					s_tester_nx_state <= ST_A;
				end if;

			when others => -- Step Zero is INIT IDLE, waiting for exclusive switch
				           -- position to then transition to INIT Measure Mode or
				           -- INIT Linked Mode.
				o_reading_inactive    <= '1';
				o_active_init_display <= '0';
				o_active_run_display  <= '0';
				s_mode_is_measur_val  <= s_mode_is_measur_aux;
				s_mode_is_linked_val  <= s_mode_is_linked_aux;

				if (i_acl_command_ready = '1') then
					if (i_switches_debounced = "0001") then -- switch 0 solitary
						s_tester_nx_state <= ST_1;
					elsif (i_switches_debounced = "0010") then -- switch 1 solitary
						s_tester_nx_state <= ST_5;
					else
						s_tester_nx_state <= ST_0;
					end if;
				else
					s_tester_nx_state <= ST_0;
				end if;
		end case;
	end process p_tester_fsm_comb;

end architecture rtl;
--------------------------------------------------------------------------------
