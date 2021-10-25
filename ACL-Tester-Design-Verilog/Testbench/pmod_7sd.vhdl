--------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2021 Timothy Stotts
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
-- \file pmod_7sd.vhdl
--
-- \brief OSVVM testbench component: Simulation Model of Digilent Inc.
-- Pmod SSD (7SD) external peripheral in two digit multiplexing.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
context osvvm.OsvvmContext;

library work;
--------------------------------------------------------------------------------
entity tbc_pmod_7sd is
    port(
        TBID : in AlertLogIDType;
        BarrierTestStart : inout std_logic;
        BarrierLogStart : inout std_logic;
        ci_mux_ena : in std_logic;
        ci_mux_dat : in std_logic_vector(6 downto 0)
        );
end entity tbc_pmod_7sd;
--------------------------------------------------------------------------------
architecture simulation_default of tbc_pmod_7sd is
    -- A function to determine the hexademical, 0-9,A-F , value of the 7SD digit
    -- displayed.
    function ssd_to_unsigned(val : std_logic_vector(6 downto 0))
    return unsigned is
        variable v_ret : unsigned(3 downto 0);
    begin
        case val is
            when "0111111" => v_ret := x"0";
            when "0000110" => v_ret := x"1";
            when "1011011" => v_ret := x"2";
            when "1001111" => v_ret := x"3";
            when "1100110" => v_ret := x"4";
            when "1101101" => v_ret := x"5";
            when "1111101" => v_ret := x"6";
            when "0000111" => v_ret := x"7";
            when "1111111" => v_ret := x"8";
            when "1100111" => v_ret := x"9";
            when "1110111" => v_ret := x"A";
            when "1111100" => v_ret := x"B";
            when "0111001" => v_ret := x"C";
            when "1011110" => v_ret := x"D";
            when "1111001" => v_ret := x"E";
            when "1110001" => v_ret := x"F";
            when others => v_ret := "UUUU";
        end case;

        return v_ret;
    end function ssd_to_unsigned;

    -- Simulation logging ID for this architecture.
    signal ModelID : AlertLogIDType;
begin
    -- Simulation initialization
    p_sim_init : process
        variable ID : AlertLogIDType;
    begin
        wait for 0 ns;
        WaitForBarrier(BarrierTestStart);
        ID := GetAlertLogID(PathTail(tbc_pmod_7sd'path_name), TBID);
        ModelID <= ID;

        wait on ModelID;
        Log(ModelID, "Starting monitoring emulation of Pmod SSD (7SD).", ALWAYS);
        wait;
    end process p_sim_init;

    -- Print the interpretation of the Pmod 7SD digit selected for display.
    -- By monitoring the signal \ref ci_mux_ena , the process toggles between
    -- digit 0 and digit 1 to monitor and indicate an interpretation of the
    -- displayed digit.
    p_receive_display_value : process
        variable val_of_7sd : unsigned(3 downto 0);
        variable val_is_valid : std_logic;
    begin
        wait for 0 ns;
        WaitForBarrier(BarrierLogStart);
        
        l_7seg_monitor : loop
            wait on ci_mux_ena;
            wait for 100 ns;
            val_of_7sd := ssd_to_unsigned(ci_mux_dat);
            val_is_valid := std_logic(val_of_7sd(0));

            if (val_is_valid = 'U') then
                -- The function \ref ssd_to_unsigned found that an invalid digit
                -- value is being driven by the FPGA, or that the display is OFF.

                if (ci_mux_dat = "0000000") then
                    -- Display digit is off.
                    Log(ModelID, "7SD Digit " & to_string(ci_mux_ena) &
                        " is turned OFF: " & to_string(ci_mux_dat),
                        INFO);
                else
                    -- Alert that the 7SD Digit is invalid for the purposes of
                    -- of the DUT driving 0-9,A-F, or OFF, and no other value.
                    Alert(ModelID, "7SD Digit " & to_string(ci_mux_ena) &
                        " is displaying an invalid value: " &
                        to_string(ci_mux_dat),
                        WARNING);
                end if;
            else
                -- Log the 7SD Digit value displayed. The enable signal
                -- \ref ci_mux_ena determines if the display is currently
                -- driving Digit 0 or Digit 1.
                Log(ModelID, "7SD Digit " & to_string(ci_mux_ena) &
                    " is displaying character: " & to_hstring(val_of_7sd) &
                    " (" & to_string(ci_mux_dat) & ")",
                    INFO);
            end if;
        end loop l_7seg_monitor;
        wait;
    end process p_receive_display_value;
end architecture simulation_default;
--------------------------------------------------------------------------------
