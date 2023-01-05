/*------------------------------------------------------------------------------
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
------------------------------------------------------------------------------*/
/**-----------------------------------------------------------------------------
-- \file thresh_presets_selector.v
--
-- \brief A threshold presets selector with a parameter input of the
-- configuration values.
------------------------------------------------------------------------------*/
//------------------------------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module thresh_presets_selector(i_clk_20mhz, i_rst_20mhz, i_btn_chg_preset,
    o_value_enum, o_value_thresh, o_value_timer);

parameter [16*16-1:0] parm_presets_config_thresholds = {
    16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000,
    16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000};
parameter [16*16-1:0] parm_presets_config_timers = {
    16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000,
    16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000};

input wire i_clk_20mhz;
input wire i_rst_20mhz;
input wire i_btn_chg_preset;
output reg [3:0] o_value_enum;
output reg [15:0] o_value_thresh;
output reg [15:0] o_value_timer;

// Part 2: Declarations---------------------------------------------------------
localparam [3:0] ST_0 = 0;
localparam [3:0] ST_1 = 1;
localparam [3:0] ST_2 = 2;
localparam [3:0] ST_3 = 3;
localparam [3:0] ST_4 = 4;
localparam [3:0] ST_5 = 5;
localparam [3:0] ST_6 = 6;
localparam [3:0] ST_7 = 7;
localparam [3:0] ST_8 = 8;
localparam [3:0] ST_9 = 9;
localparam [3:0] ST_A = 10;
localparam [3:0] ST_B = 11;
localparam [3:0] ST_C = 12;
localparam [3:0] ST_D = 13;
localparam [3:0] ST_E = 14;
localparam [3:0] ST_F = 15;

reg [3:0] s_thrpset_pr_state;
reg [3:0] s_thrpset_nx_state;

// FSM state register
always @(posedge i_clk_20mhz)
begin: p_fsm_state
    if (i_rst_20mhz) s_thrpset_pr_state <= ST_0;
    else s_thrpset_pr_state <= s_thrpset_nx_state;
end

// FSM combinatorial logic
always @(s_thrpset_pr_state, i_btn_chg_preset)
begin: p_fsm_comb
    case (s_thrpset_pr_state)
        ST_1: begin
            o_value_enum = 4'h1;
            o_value_thresh = parm_presets_config_thresholds[15*16-1-:16];
            o_value_timer = parm_presets_config_timers[15*16-1-:16];
            if (i_btn_chg_preset) s_thrpset_nx_state = ST_2;
            else s_thrpset_nx_state = ST_1;
        end
        ST_2: begin
            o_value_enum = 4'h2;
            o_value_thresh = parm_presets_config_thresholds[14*16-1-:16];
            o_value_timer = parm_presets_config_timers[14*16-1-:16];
            if (i_btn_chg_preset) s_thrpset_nx_state = ST_3;
            else s_thrpset_nx_state = ST_2;
        end
        ST_3: begin
            o_value_enum = 4'h3;
            o_value_thresh = parm_presets_config_thresholds[13*16-1-:16];
            o_value_timer = parm_presets_config_timers[13*16-1-:16];
            if (i_btn_chg_preset) s_thrpset_nx_state = ST_4;
            else s_thrpset_nx_state = ST_3;
        end
        ST_4: begin
            o_value_enum = 4'h4;
            o_value_thresh = parm_presets_config_thresholds[12*16-1-:16];
            o_value_timer = parm_presets_config_timers[12*16-1-:16];
            if (i_btn_chg_preset) s_thrpset_nx_state = ST_5;
            else s_thrpset_nx_state = ST_4;
        end
        ST_5: begin
            o_value_enum = 4'h5;
            o_value_thresh = parm_presets_config_thresholds[11*16-1-:16];
            o_value_timer = parm_presets_config_timers[11*16-1-:16];
            if (i_btn_chg_preset) s_thrpset_nx_state = ST_6;
            else s_thrpset_nx_state = ST_5;
        end
        ST_6: begin
            o_value_enum = 4'h6;
            o_value_thresh = parm_presets_config_thresholds[10*16-1-:16];
            o_value_timer = parm_presets_config_timers[10*16-1-:16];
            if (i_btn_chg_preset) s_thrpset_nx_state = ST_7;
            else s_thrpset_nx_state = ST_6;
        end
        ST_7: begin
            o_value_enum = 4'h7;
            o_value_thresh = parm_presets_config_thresholds[9*16-1-:16];
            o_value_timer = parm_presets_config_timers[9*16-1-:16];
            if (i_btn_chg_preset) s_thrpset_nx_state = ST_8;
            else s_thrpset_nx_state = ST_7;
        end
        ST_8: begin
            o_value_enum = 4'h8;
            o_value_thresh = parm_presets_config_thresholds[8*16-1-:16];
            o_value_timer = parm_presets_config_timers[8*16-1-:16];
            if (i_btn_chg_preset) s_thrpset_nx_state = ST_9;
            else s_thrpset_nx_state = ST_8;
        end
        ST_9: begin
            o_value_enum = 4'h9;
            o_value_thresh = parm_presets_config_thresholds[7*16-1-:16];
            o_value_timer = parm_presets_config_timers[7*16-1-:16];
            if (i_btn_chg_preset) s_thrpset_nx_state = ST_0; // only increment 0 to 9, even though configuration is 0 to F
            else s_thrpset_nx_state = ST_9;
        end
        default: begin // ST_0
            o_value_enum = 4'h0;
            o_value_thresh = parm_presets_config_thresholds[16*16-1-:16];
            o_value_timer = parm_presets_config_timers[16*16-1-:16];
            if (i_btn_chg_preset) s_thrpset_nx_state = ST_1;
            else s_thrpset_nx_state = ST_0;
        end
    endcase // s_thrpset_pr_state
end

endmodule
//------------------------------------------------------------------------------
