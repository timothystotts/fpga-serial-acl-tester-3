-------------------------------------------------------------------------------
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
-- \file thresh_presets_pkg.vhdl
--
-- \brief Constants that are usable presets for the ADXL362 registers, threshold,
-- and timer.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.thresh_presets_selector_pkg.all;

package thresh_presets_pkg is
    constant c_thresh_presets_active_a : t_val_presets_group := (
        thresholds => (32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 65000, 65000, 65000, 65000, 65000, 65000),
        timers => (16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 65000, 65000, 65000, 65000, 65000, 65000)
        );

    constant c_thresh_presets_inactive_a : t_val_presets_group := (
        thresholds => (16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 65000, 65000, 65000, 65000, 65000, 65000),
        timers => (32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 65000, 65000, 65000, 65000, 65000, 65000)
        );
end package thresh_presets_pkg;
--------------------------------------------------------------------------------
