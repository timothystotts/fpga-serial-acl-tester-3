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
-- \file led_palette_pulser.vhdl
--
-- \brief A simple pulser to generate palette values for \ref led_pwm_driver.vhdl
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.led_pwm_driver_pkg.all;
--------------------------------------------------------------------------------
entity led_palette_pulser is
    generic(
        -- color emitter and pwm parameters
        parm_color_led_count        : integer := 4;
        parm_basic_led_count        : integer := 4;
        parm_FCLK                   : integer := 40_000_000;
        parm_adjustments_per_second : integer := 128
    );
    port(
        -- clock and reset
        i_clk  : in std_logic;
        i_srst : in std_logic;

        -- palette out values
        o_color_led_red_value   : out t_led_color_values((parm_color_led_count - 1) downto 0);
        o_color_led_green_value : out t_led_color_values((parm_color_led_count - 1) downto 0);
        o_color_led_blue_value  : out t_led_color_values((parm_color_led_count - 1) downto 0);
        o_basic_led_lumin_value : out t_led_color_values((parm_basic_led_count - 1) downto 0);

        -- system statuses to adjust LEDs by
        i_active_init_display       : in std_logic;
        i_active_run_display        : in std_logic;
        i_mode_is_measur_aux        : in std_logic;
        i_mode_is_linked_aux        : in std_logic;
        i_acl2_activity_stretched   : in std_logic;
        i_acl2_inactivity_stretched : in std_logic;
        i_acl2_awake_status         : in std_logic;
        i_sw0_selected              : in std_logic;
        i_sw1_selected              : in std_logic
    );
end entity led_palette_pulser;
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
architecture rtl of led_palette_pulser is
    -- Color LED PWM driver input scale signals for 8-bit color mixing that
    -- makes the color LEDs appear to pulse in luminostiry and hue.
    signal s_tester_led_ce : std_logic;

    signal s_ld0_red_value   : std_logic_vector(7 downto 0);
    signal s_ld1_red_value   : std_logic_vector(7 downto 0);
    signal s_ld2_red_value   : std_logic_vector(7 downto 0);
    signal s_ld3_red_value   : std_logic_vector(7 downto 0);
    signal s_ld0_green_value : std_logic_vector(7 downto 0);
    signal s_ld1_green_value : std_logic_vector(7 downto 0);
    signal s_ld2_green_value : std_logic_vector(7 downto 0);
    signal s_ld3_green_value : std_logic_vector(7 downto 0);
    signal s_ld0_blue_value  : std_logic_vector(7 downto 0);
    signal s_ld1_blue_value  : std_logic_vector(7 downto 0);
    signal s_ld2_blue_value  : std_logic_vector(7 downto 0);
    signal s_ld3_blue_value  : std_logic_vector(7 downto 0);
    signal s_ld4_basic_value : std_logic_vector(7 downto 0);
    signal s_ld5_basic_value : std_logic_vector(7 downto 0);
    signal s_ld6_basic_value : std_logic_vector(7 downto 0);
    signal s_ld7_basic_value : std_logic_vector(7 downto 0);

    signal s_ld0_red_pulse   : unsigned(5 downto 0);
    signal s_ld0_green_pulse : unsigned(5 downto 0);
    signal s_ld0_blue_pulse  : unsigned(5 downto 0);
    signal s_ld0_dir_pulse   : std_logic;
    signal s_ld0_led_pulse   : unsigned(5 downto 0);

    signal s_ld1_red_pulse   : unsigned(5 downto 0);
    signal s_ld1_green_pulse : unsigned(5 downto 0);
    signal s_ld1_blue_pulse  : unsigned(5 downto 0);
    signal s_ld1_dir_pulse   : std_logic;
    signal s_ld1_led_pulse   : unsigned(5 downto 0);

    signal s_ld2_red_pulse   : unsigned(5 downto 0);
    signal s_ld2_green_pulse : unsigned(5 downto 0);
    signal s_ld2_blue_pulse  : unsigned(5 downto 0);
    signal s_ld2_dir_pulse   : std_logic;
    signal s_ld2_led_pulse   : unsigned(5 downto 0);

    signal s_ld3_red_pulse   : unsigned(5 downto 0);
    signal s_ld3_green_pulse : unsigned(5 downto 0);
    signal s_ld3_blue_pulse  : unsigned(5 downto 0);
    signal s_ld3_dir_pulse   : std_logic;
    signal s_ld3_led_pulse   : unsigned(5 downto 0);
begin
    -- A clock enable divider for the process \ref p_tester_fsm_display .
    -- Divides the parm_FCLK MHz clock down to 128 enables per 1.5 seconds.
    u_clock_enable_led_pulse : entity work.clock_enable_divider(rtl)
        generic map (
            par_ce_divisor => parm_FCLK / parm_adjustments_per_second
        )
        port map (
            o_ce_div  => s_tester_led_ce,
            i_clk_mhz => i_clk,
            i_rst_mhz => i_srst,
            i_ce_mhz  => '1'
        );

    -- Tester FSM registered outputs to multicolor LED 0:3 to indicate the
    -- execution state of \ref p_tester_fsm_state and \ref p_tester_comb and also
    -- the status register Activity and Inactivity. Also displayed on LED 4
    -- is the AWAKE state of the PMOD ACL2; and on LED 6,7 the Switch 0
    -- and Switch 1 debounced positions.
    g_led_out_color_2 : if (parm_color_led_count = 2) generate
    begin
        o_color_led_red_value   <= (s_ld3_red_value, s_ld2_red_value);
        o_color_led_green_value <= (s_ld3_green_value, s_ld2_green_value);
        o_color_led_blue_value  <= (s_ld3_blue_value, s_ld2_blue_value);
    end generate g_led_out_color_2;

    g_led_out_color_4 : if (parm_color_led_count /= 2) generate
    begin
        o_color_led_red_value   <= (s_ld3_red_value, s_ld2_red_value, s_ld1_red_value, s_ld0_red_value);
        o_color_led_green_value <= (s_ld3_green_value, s_ld2_green_value, s_ld1_green_value, s_ld0_green_value);
        o_color_led_blue_value  <= (s_ld3_blue_value, s_ld2_blue_value, s_ld1_blue_value, s_ld0_blue_value);
    end generate g_led_out_color_4;

    o_basic_led_lumin_value <= (s_ld7_basic_value, s_ld6_basic_value, s_ld5_basic_value, s_ld4_basic_value);

    s_ld0_red_value   <= std_logic_vector(s_ld0_red_pulse) & "11";
    s_ld0_green_value <= std_logic_vector(s_ld0_green_pulse) & "11";
    s_ld0_blue_value  <= std_logic_vector(s_ld0_blue_pulse) & "11";

    s_ld1_red_value   <= "0" & std_logic_vector(s_ld1_red_pulse) & "1";
    s_ld1_green_value <= "0" & std_logic_vector(s_ld1_green_pulse) & "1";
    s_ld1_blue_value  <= "0" & std_logic_vector(s_ld1_blue_pulse) & "1";

    s_ld2_red_value   <= std_logic_vector(s_ld2_red_pulse) & "11";
    s_ld2_green_value <= std_logic_vector(s_ld2_green_pulse) & "11";
    s_ld2_blue_value  <= std_logic_vector(s_ld2_blue_pulse) & "11";

    s_ld3_red_value   <= std_logic_vector(s_ld3_red_pulse) & "11";
    s_ld3_green_value <= std_logic_vector(s_ld3_green_pulse) & "11";
    s_ld3_blue_value  <= std_logic_vector(s_ld3_blue_pulse) & "11";

    p_tester_led_pulse : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_srst = '1') then
                -- Upon reset, stage the pulses to be approximately a value of 21 apart
                s_ld0_dir_pulse <= '0';
                s_ld0_led_pulse <= "000001";
                s_ld1_dir_pulse <= '0';
                s_ld1_led_pulse <= "010101";
                s_ld2_dir_pulse <= '0';
                s_ld2_led_pulse <= "101010";
                s_ld3_dir_pulse <= '0';
                s_ld3_led_pulse <= "111111";

            elsif (s_tester_led_ce = '1') then

                -- Rotate up and down a pulse value to be used for LD0
                if (s_ld0_dir_pulse = '1') then
                    if (s_ld0_led_pulse = "111111") then
                        s_ld0_dir_pulse <= '0';
                    else
                        s_ld0_led_pulse <= s_ld0_led_pulse + 1;
                    end if;
                else
                    if (s_ld0_led_pulse = "000001") then
                        s_ld0_dir_pulse <= '1';
                    else
                        s_ld0_led_pulse <= s_ld0_led_pulse - 1;
                    end if;
                end if;
                -- Rotate up and down a pulse value to be used for LD1
                if (s_ld1_dir_pulse = '1') then
                    if (s_ld1_led_pulse = "111111") then
                        s_ld1_dir_pulse <= '0';
                    else
                        s_ld1_led_pulse <= s_ld1_led_pulse + 1;
                    end if;
                else
                    if (s_ld1_led_pulse = "000001") then
                        s_ld1_dir_pulse <= '1';
                    else
                        s_ld1_led_pulse <= s_ld1_led_pulse - 1;
                    end if;
                end if;
                -- Rotate up and down a pulse value to be used for LD2
                if (s_ld2_dir_pulse = '1') then
                    if (s_ld2_led_pulse = "111111") then
                        s_ld2_dir_pulse <= '0';
                    else
                        s_ld2_led_pulse <= s_ld2_led_pulse + 1;
                    end if;
                else
                    if (s_ld2_led_pulse = "000001") then
                        s_ld2_dir_pulse <= '1';
                    else
                        s_ld2_led_pulse <= s_ld2_led_pulse - 1;
                    end if;
                end if;
                -- Rotate up and down a pulse value to be used for LD3
                if (s_ld3_dir_pulse = '1') then
                    if (s_ld3_led_pulse = "111111") then
                        s_ld3_dir_pulse <= '0';
                    else
                        s_ld3_led_pulse <= s_ld3_led_pulse + 1;
                    end if;
                else
                    if (s_ld3_led_pulse = "000001") then
                        s_ld3_dir_pulse <= '1';
                    else
                        s_ld3_led_pulse <= s_ld3_led_pulse - 1;
                    end if;
                end if;

            end if;
        end if;
    end process p_tester_led_pulse;

    p_tester_led_display : process(i_clk)
    begin
        if rising_edge(i_clk) then
            -- LED 0 will be red when tester is initializing.
            -- LED 0 will be green when tester is running.
            -- LED 0 will be blue when tester is not working at all.
            if (i_active_init_display = '1') then
                s_ld0_red_pulse   <= s_ld0_led_pulse;
                s_ld0_green_pulse <= "000001";
                s_ld0_blue_pulse  <= "000001";
            elsif (i_active_run_display = '1') then
                s_ld0_red_pulse   <= "000001";
                s_ld0_green_pulse <= s_ld0_led_pulse;
                s_ld0_blue_pulse  <= "000001";
            else
                s_ld0_red_pulse   <= "000001";
                s_ld0_green_pulse <= "000001";
                s_ld0_blue_pulse  <= s_ld0_led_pulse;
            end if;

            -- LED 1 will be red when tester is not working at all.
            -- LED 1 will be white when tester is measuring continuously.
            -- LED 1 will be purple when tester is only detecting motion toggle.
            if (i_mode_is_measur_aux = '1') then
                s_ld1_red_pulse   <= s_ld1_led_pulse;
                s_ld1_green_pulse <= s_ld1_led_pulse;
                s_ld1_blue_pulse  <= s_ld1_led_pulse;
            elsif (i_mode_is_linked_aux = '1') then
                s_ld1_red_pulse   <= s_ld1_led_pulse;
                s_ld1_green_pulse <= "000001";
                s_ld1_blue_pulse  <= s_ld1_led_pulse;
            else
                s_ld1_red_pulse   <= s_ld1_led_pulse;
                s_ld1_green_pulse <= "000001";
                s_ld1_blue_pulse  <= "000001";
            end if;

            -- LED 2 is Red when no Activity detect, Green when Activity detect.
            if ((i_acl2_activity_stretched = '1') and (i_mode_is_linked_aux = '1')) then
                s_ld2_red_pulse   <= "000001";
                s_ld2_green_pulse <= "111111";
                s_ld2_blue_pulse  <= "000001";
            else
                s_ld2_red_pulse   <= s_ld2_led_pulse;
                s_ld2_green_pulse <= "0000" & s_ld2_led_pulse(1 downto 0);
                s_ld2_blue_pulse  <= "000000";
            end if;

            -- LED 3 is Red when no Inactivity detect, Green when Inactivity detect.
            if ((i_acl2_inactivity_stretched = '1') and (i_mode_is_linked_aux = '1')) then
                s_ld3_red_pulse   <= "000001";
                s_ld3_green_pulse <= "111111";
                s_ld3_blue_pulse  <= "000001";
            else
                s_ld3_red_pulse   <= s_ld3_led_pulse;
                s_ld3_green_pulse <= "0000" & s_ld3_led_pulse(1 downto 0);
                s_ld3_blue_pulse  <= "000000";
            end if;

            -- LED4 is AWAKE status from the status register
            if (i_acl2_awake_status = '1') Then
                s_ld4_basic_value <= x"FF";
            else
                s_ld4_basic_value <= x"00";
            end if;

            -- LED 5 is unused at this time.
            s_ld5_basic_value <= x"00";

            -- LED 6, LED 7, indicate the debounced switch positions.
            if (i_sw0_selected = '1') Then
                s_ld6_basic_value <= x"FF";
            else
                s_ld6_basic_value <= x"00";
            end if;

            if (i_sw1_selected = '1') Then
                s_ld7_basic_value <= x"FF";
            else
                s_ld7_basic_value <= x"00";
            end if;
        end if;
    end process p_tester_led_display;
end architecture rtl;
--------------------------------------------------------------------------------
