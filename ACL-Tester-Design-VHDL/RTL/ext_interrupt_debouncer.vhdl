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
-- \file ext_interrupt_debouncer.vhdl
--
-- \brief A simple 1 microsecond signal synchronizer and debouncer to filter-out
--        glitches on an external Interrupt line from an external Integrated
--        Circuit.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--------------------------------------------------------------------------------
entity ext_interrupt_debouncer is
	port(
		o_int_deb : out std_logic;
		i_clk_20mhz : in std_logic;
		i_rst_20mhz : in std_logic;
		ei_interrupt : in std_logic
		);
end entity ext_interrupt_debouncer;
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
architecture moore_fsm of ext_interrupt_debouncer is
	-- Debouncer FSM states.
	type t_intdeb_state is (ST_A, ST_B, ST_C, ST_D);

	-- FSM state signals for Present and Next.
	signal s_intdeb_pr_state : t_intdeb_state;
	signal s_intdeb_nx_state : t_intdeb_state;

	-- Xilinx attributes for Gray encoding of the FSM and safe state is Default
    -- State.
    attribute fsm_encoding : string;
    attribute fsm_safe_state : string;
	attribute fsm_encoding of s_intdeb_pr_state: signal is "gray";
	attribute fsm_safe_state of s_intdeb_pr_state: signal is "default_state";

	-- Debouncer Timer parameters.
	constant c_intdeb_timer1_count : natural := 20; -- 1 microsecond time at 20 MHz
	constant c_intdeb_timer1_max : natural := c_intdeb_timer1_count - 1;

	-- Strategy #1 timer implementation.
	signal s_t : natural range 0 to c_intdeb_timer1_max;

	-- Resulting debounced interrupt signal.
	signal s_int_deb : std_logic;

	-- Variables for synchronizing the external interrupt input signal.
	signal si_interrupt_meta : std_logic;
	signal si_interrupt_sync : std_logic;
begin

-- Input synchronizer to mitigate metastability on the interrupt input. This is
-- actually necessary as a metastable input into the FSM LUT and FF synthesized
-- encoding could cause more than one location of the input value to be
-- interpreted differently, causing the FSM to produce invalid behavior, (not
-- according to design).
p_sync_interrupt: process(i_clk_20mhz)
begin
	if rising_edge(i_clk_20mhz) then
		si_interrupt_sync <= si_interrupt_meta;
		si_interrupt_meta <= ei_interrupt;
	end if;
end process p_sync_interrupt;

-- Timer with strategy #1 implementation. The timer re-zeroes on a debouncer FSM
-- state transition; and it caps at the constant parameter c_tmax.
p_fsm_timer : process(i_clk_20mhz)
begin
	if rising_edge(i_clk_20mhz) then
		if (i_rst_20mhz = '1') then
			s_t <= 0;
		else
			if (s_intdeb_pr_state /= s_intdeb_nx_state) then
				s_t <= 0;
			elsif (s_t /= c_intdeb_timer1_max) then
				s_t <= s_t + 1;
			end if;
		end if;
	end if;
end process p_fsm_timer;

-- FSM state register for transition of the FSM next state propagating to
-- current state, on the positive edge of the clock.
p_fsm_state: process(i_clk_20mhz)
begin
	if rising_edge(i_clk_20mhz) then
		if (i_rst_20mhz = '1') then
			s_intdeb_pr_state <= ST_A;
		else
			s_intdeb_pr_state <= s_intdeb_nx_state;
		end if;
	end if;
end process p_fsm_state;

-- FSM combinatorial logic providing a single output value \ref s_int_deb,
-- as well as setting-up the next state value to propagate on the next
-- positive clock edge.
p_fsm_nx_output: process(s_intdeb_pr_state, si_interrupt_sync, s_t)
begin
	case (s_intdeb_pr_state) is
	when ST_B =>
		-- State B. Hold the debounced signal at zero. If the stable input ever
		-- transitions back to zero, then transition back to State A. If the
		-- timer elapses for a full duration of the signal being one, then
		-- transition the state to State C.
		s_int_deb <= '0';
		if (si_interrupt_sync = '0') then
			s_intdeb_nx_state <= ST_A;
		elsif (s_t >= c_intdeb_timer1_count - 2) then
			s_intdeb_nx_state <= ST_C;
		else
			s_intdeb_nx_state <= ST_B;
		end if;
	when ST_C =>
		-- State C. Hold the debounced signal at one. If the stable input value
		-- transitions to zero, then transition to State D to count a timer
		-- time while waiting to change the debounced output to zero.
		s_int_deb <= '1';
		if (si_interrupt_sync = '0') then
			s_intdeb_nx_state <= ST_D;
		else
			s_intdeb_nx_state <= ST_C;
		end if;
	when ST_D =>
		-- State D. Hold the debounced signal at one. If the stable input ever
		-- transitions back to one, then transition back to State C. If the
		-- timer elapses for a full duration of the signal being zero, then
		-- transition the state to State A.
		s_int_deb <= '1';
		if (si_interrupt_sync = '1') then
			s_intdeb_nx_state <= ST_C;
		elsif (s_t >= c_intdeb_timer1_count - 2) then
			s_intdeb_nx_state <= ST_A;
		else
			s_intdeb_nx_state <= ST_D;
		end if;
	when others => -- ST_A
		-- State A. Hold the debounced signal at zero. If the stable input value
		-- transitions to one, then transition to State B to count a timer
		-- time while waiting to change the debounced output to one.
		s_int_deb <= '0';
		if (si_interrupt_sync = '1') then
			s_intdeb_nx_state <= ST_B;
		else
			s_intdeb_nx_state <= ST_A;
		end if;
	end case;
end process p_fsm_nx_output;

-- The debounced interrupt produced by the combinatorial logic is output here
-- without an extra registration.
o_int_deb <= s_int_deb;

end architecture moore_fsm;
--------------------------------------------------------------------------------
