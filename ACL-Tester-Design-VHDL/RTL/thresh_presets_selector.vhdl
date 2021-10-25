-------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020 Timothy Stotts
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
-- \file thresh_presets_selector.vhdl
--
-- \brief A threshold presets selector with a parameter input of the
-- configuration values.
--------------------------------------------------------------------------------
package thresh_presets_selector_pkg is
	subtype t_val_thresh is natural range 0 to 2**16-1;
	subtype t_val_timer is natural range 0 to 2**16-1;

	type t_val_value_thresh_array is array(0 to 15) of t_val_thresh;
	type t_val_value_timer_array is array(0 to 15) of t_val_timer;

	type t_val_presets_group is record
		thresholds : t_val_value_thresh_array;
		timers : t_val_value_timer_array;
	end record t_val_presets_group;

end package thresh_presets_selector_pkg;

--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.thresh_presets_selector_pkg.all;
--------------------------------------------------------------------------------
entity thresh_presets_selector is
	generic(
		parm_presets_config : t_val_presets_group
		);
	port(
		i_clk_20mhz : in  std_logic;
		i_rst_20mhz : in  std_logic;
		i_btn_chg_preset  : in  std_logic;
		o_value_enum : out std_logic_vector(3 downto 0);
		o_value_thresh : out std_logic_vector(15 downto 0);
		o_value_timer : out std_logic_vector(15 downto 0)
	);
end entity thresh_presets_selector;
--------------------------------------------------------------------------------
architecture rtl of thresh_presets_selector is
	type t_state is (ST_0, ST_1, ST_2, ST_3, ST_4, ST_5, ST_6, ST_7, ST_8, ST_9,
		ST_A, ST_B, ST_C, ST_D, ST_E, ST_F);
	signal s_thrpset_pr_state : t_state;
	signal s_thrpset_nx_state : t_state;
begin
	-- FSM state register:
	p_fsm_state : process(i_clk_20mhz)
	begin
		if rising_edge(i_clk_20mhz) then
			if (i_rst_20mhz = '1') then
				s_thrpset_pr_state <= ST_0;
			else
				s_thrpset_pr_state <= s_thrpset_nx_state;
			end if;
		end if;
	end process p_fsm_state;

	-- FSM combinational logic:
	p_fsm_comb : process(s_thrpset_pr_state, i_btn_chg_preset)
	begin
		case (s_thrpset_pr_state) is
			when ST_1 =>
				o_value_enum <= x"1";
				o_value_thresh <= std_logic_vector(to_unsigned(parm_presets_config.thresholds(1), 16));
				o_value_timer <= std_logic_vector(to_unsigned(parm_presets_config.timers(1), 16));
				if (i_btn_chg_preset = '1') then
					s_thrpset_nx_state <= ST_2;
				else
					s_thrpset_nx_state <= ST_1;
				end if;
			when ST_2 =>
				o_value_enum <= x"2";
				o_value_thresh <= std_logic_vector(to_unsigned(parm_presets_config.thresholds(2), 16));
				o_value_timer <= std_logic_vector(to_unsigned(parm_presets_config.timers(2), 16));
				if (i_btn_chg_preset = '1') then
					s_thrpset_nx_state <= ST_3;
				else
					s_thrpset_nx_state <= ST_2;
				end if;
			when ST_3 =>
				o_value_enum <= x"3";
				o_value_thresh <= std_logic_vector(to_unsigned(parm_presets_config.thresholds(3), 16));
				o_value_timer <= std_logic_vector(to_unsigned(parm_presets_config.timers(3), 16));
				if (i_btn_chg_preset = '1') then
					s_thrpset_nx_state <= ST_4;
				else
					s_thrpset_nx_state <= ST_3;
				end if;
			when ST_4 =>
				o_value_enum <= x"4";
				o_value_thresh <= std_logic_vector(to_unsigned(parm_presets_config.thresholds(4), 16));
				o_value_timer <= std_logic_vector(to_unsigned(parm_presets_config.timers(4), 16));
				if (i_btn_chg_preset = '1') then
					s_thrpset_nx_state <= ST_5;
				else
					s_thrpset_nx_state <= ST_4;
				end if;
			when ST_5 =>
				o_value_enum <= x"5";
				o_value_thresh <= std_logic_vector(to_unsigned(parm_presets_config.thresholds(5), 16));
				o_value_timer <= std_logic_vector(to_unsigned(parm_presets_config.timers(5), 16));
				if (i_btn_chg_preset = '1') then
					s_thrpset_nx_state <= ST_6;
				else
					s_thrpset_nx_state <= ST_5;
				end if;
			when ST_6 =>
				o_value_enum <= x"6";
				o_value_thresh <= std_logic_vector(to_unsigned(parm_presets_config.thresholds(6), 16));
				o_value_timer <= std_logic_vector(to_unsigned(parm_presets_config.timers(6), 16));
				if (i_btn_chg_preset = '1') then
					s_thrpset_nx_state <= ST_7;
				else
					s_thrpset_nx_state <= ST_6;
				end if;
			when ST_7 =>
				o_value_enum <= x"7";
				o_value_thresh <= std_logic_vector(to_unsigned(parm_presets_config.thresholds(7), 16));
				o_value_timer <= std_logic_vector(to_unsigned(parm_presets_config.timers(7), 16));
				if (i_btn_chg_preset = '1') then
					s_thrpset_nx_state <= ST_8;
				else
					s_thrpset_nx_state <= ST_7;
				end if;
			when ST_8 =>
				o_value_enum <= x"8";
				o_value_thresh <= std_logic_vector(to_unsigned(parm_presets_config.thresholds(8), 16));
				o_value_timer <= std_logic_vector(to_unsigned(parm_presets_config.timers(8), 16));
				if (i_btn_chg_preset = '1') then
					s_thrpset_nx_state <= ST_9;
				else
					s_thrpset_nx_state <= ST_8;
				end if;
			when ST_9 =>
				o_value_enum <= x"9";
				o_value_thresh <= std_logic_vector(to_unsigned(parm_presets_config.thresholds(9), 16));
				o_value_timer <= std_logic_vector(to_unsigned(parm_presets_config.timers(9), 16));
				if (i_btn_chg_preset = '1') then
					s_thrpset_nx_state <= ST_0; -- only increment 0 to 9, even though configuration is 0 to F
				else
					s_thrpset_nx_state <= ST_9;
				end if;
			when others => -- ST_0
				o_value_enum <= x"0";
				o_value_thresh <= std_logic_vector(to_unsigned(parm_presets_config.thresholds(0), 16));
				o_value_timer <= std_logic_vector(to_unsigned(parm_presets_config.timers(0), 16));
				if (i_btn_chg_preset = '1') then
					s_thrpset_nx_state <= ST_1;
				else
					s_thrpset_nx_state <= ST_0;
				end if;
		end case;
	end process p_fsm_comb;

end architecture rtl;
--------------------------------------------------------------------------------
