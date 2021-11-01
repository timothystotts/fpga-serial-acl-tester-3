/*------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020-2021 Timothy Stotts
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
-- \file thresh_presets_selector.sv
--
-- \brief A threshold presets selector with a parameter input of the
-- configuration values.
------------------------------------------------------------------------------*/
`begin_keywords "1800-2009"
//------------------------------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module thresh_presets_selector
	#(parameter
		logic [16*16-1:0] parm_presets_config_thresholds = {
			16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 
			16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000},
		logic [16*16-1:0] parm_presets_config_timers = {
			16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 
			16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000, 16'd65000}
		)
	(
		input logic i_clk_20mhz,
		input logic i_rst_20mhz,
		input logic i_btn_chg_preset,
		output logic [3:0] o_value_enum,
		output logic [15:0] o_value_thresh,
		output logic [15:0] o_value_timer
		);


// Part 2: Declarations---------------------------------------------------------
timeunit 1ns;
timeprecision 1ps;

typedef enum logic [3:0] {
	ST_0, ST_1, ST_2, ST_3, ST_4, ST_5, ST_6, ST_7, ST_8,
	ST_9, ST_A, ST_B, ST_C, ST_D, ST_E, ST_F
} t_thrpset_state;

t_thrpset_state s_thrpset_pr_state;
t_thrpset_state s_thrpset_nx_state;

/* FSM state register */
always_ff @(posedge i_clk_20mhz)
begin: p_fsm_state
	if (i_rst_20mhz) s_thrpset_pr_state <= ST_0;
	else s_thrpset_pr_state <= s_thrpset_nx_state;
end : p_fsm_state

/* FSM combinatorial logic: */
always_comb
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
end : p_fsm_comb

endmodule : thresh_presets_selector
//------------------------------------------------------------------------------
`end_keywords
