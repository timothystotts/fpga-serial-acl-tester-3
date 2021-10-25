/*------------------------------------------------------------------------------
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
------------------------------------------------------------------------------*/
/**-----------------------------------------------------------------------------
-- \file thresh_presets_include.svh
--
-- \brief Parameters for the \ref pmod_acl2_custom_driver usage of the
-- \ref thresh_presets_selector module.
------------------------------------------------------------------------------*/
//------------------------------------------------------------------------------
`ifndef _thresh_presets_include_vh_
`define _thresh_presets_include_vh_

`define c_thresh_presets_active_a_thresholds ({16'd32, 16'd64, 16'd96, 16'd128, 16'd160, 16'd192, 16'd224, 16'd256, 16'd288, 16'd320, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000})
`define c_thresh_presets_active_a_timers ({16'd16, 16'd32, 16'd48, 16'd64, 16'd80, 16'd96, 16'd112, 16'd128, 16'd144, 16'd160, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000})

`define c_thresh_presets_inactive_a_thresholds ({16'd16, 16'd32, 16'd48, 16'd64, 16'd80, 16'd96, 16'd112, 16'd128, 16'd144, 16'd160, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000})
`define c_thresh_presets_inactive_a_timers ({16'd32, 16'd64, 16'd96, 16'd128, 16'd160, 16'd192, 16'd224, 16'd256, 16'd288, 16'd320, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000})

`endif
