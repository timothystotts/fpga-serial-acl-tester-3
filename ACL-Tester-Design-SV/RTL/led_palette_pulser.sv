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
-- \file led_palette_pulser.sv
--
-- \brief A simple pulser to generate palette values for \ref led_pwm_driver.sv .
------------------------------------------------------------------------------*/
`begin_keywords "1800-2009"
//D-FF based LED pulsing--------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module led_palette_pulser
	#(parameter
		integer parm_color_led_count = 4,
		integer parm_basic_led_count = 4,
		integer parm_FCLK = 40_000_000,
		integer parm_adjustments_per_second = 128,
		integer c_color_value_upper = 8 * parm_color_led_count - 1,
		integer c_basic_value_upper = 8 * parm_basic_led_count - 1,
		integer c_color_count_upper = parm_color_led_count - 1,
		integer c_basic_count_upper = parm_basic_led_count - 1
		)
	(
		// clock and reset
		input logic i_clk,
		input logic i_srst,
		// palette out values
		output logic [c_color_value_upper:0] o_color_led_red_value,
		output logic [c_color_value_upper:0] o_color_led_green_value,
		output logic [c_color_value_upper:0] o_color_led_blue_value,
		output logic [c_basic_value_upper:0] o_basic_led_lumin_value,
		// system statuses to adjust LEDs by
		input logic i_active_init_display,
		input logic i_active_run_display,
		input logic i_mode_is_measur_aux,
		input logic i_mode_is_linked_aux,
		input logic i_acl2_activity_stretched,
		input logic i_acl2_inactivity_stretched,
		input logic i_acl2_awake_status,
		input logic i_sw0_selected,
		input logic i_sw1_selected);

//Part 2: Declarations----------------------------------------------------------
timeunit 1ns;
timeprecision 1ps;

// Color LED PWM driver input scale signals for 8-bit color mixing that
// makes the color LEDs appear to pulse in luminostiry and hue.
logic s_tester_led_ce;

logic [7:0] s_ld0_red_value;
logic [7:0] s_ld1_red_value;
logic [7:0] s_ld2_red_value;
logic [7:0] s_ld3_red_value;
logic [7:0] s_ld0_green_value;
logic [7:0] s_ld1_green_value;
logic [7:0] s_ld2_green_value;
logic [7:0] s_ld3_green_value;
logic [7:0] s_ld0_blue_value;
logic [7:0] s_ld1_blue_value;
logic [7:0] s_ld2_blue_value;
logic [7:0] s_ld3_blue_value;
logic [7:0] s_ld4_basic_value;
logic [7:0] s_ld5_basic_value;
logic [7:0] s_ld6_basic_value;
logic [7:0] s_ld7_basic_value;

logic [5:0] s_ld0_red_pulse;
logic [5:0] s_ld0_green_pulse;
logic [5:0] s_ld0_blue_pulse;
logic s_ld0_dir_pulse;
logic [5:0] s_ld0_led_pulse;

logic [5:0] s_ld1_red_pulse;
logic [5:0] s_ld1_green_pulse;
logic [5:0] s_ld1_blue_pulse;
logic s_ld1_dir_pulse;
logic [5:0] s_ld1_led_pulse;

logic [5:0] s_ld2_red_pulse;
logic [5:0] s_ld2_green_pulse;
logic [5:0] s_ld2_blue_pulse;
logic s_ld2_dir_pulse;
logic [5:0] s_ld2_led_pulse;

logic [5:0] s_ld3_red_pulse;
logic [5:0] s_ld3_green_pulse;
logic [5:0] s_ld3_blue_pulse;
logic s_ld3_dir_pulse;
logic [5:0] s_ld3_led_pulse;

//Part 3: Statements------------------------------------------------------------
// A clock enable divider for the process \ref p_tester_fsm_display .
// Divides the 20 MHz clock down to 128 enables per 1.5 seconds.
clock_enable_divider #(
	.par_ce_divisor(parm_FCLK / parm_adjustments_per_second)
	) u_clock_enable_led_pulse (
	.o_ce_div(s_tester_led_ce),
	.i_clk_mhz(i_clk),
	.i_rst_mhz(i_srst),
	.i_ce_mhz(1'b1)
	);

/* Tester FSM registered outputs to multicolor LED 0:3 to indicate the
   execution state of \ref p_tester_fsm_state and \ref p_tester_comb and also
   the status register Activity and Inactivity. Also displayed on LED 4
   is the AWAKE state of the PMOD ACL2; and on LED 6,7 the Switch 0
   and Switch 1 debounced positions. */
if (parm_color_led_count == 2) begin
	assign o_color_led_red_value = {s_ld3_red_value, s_ld2_red_value};
	assign o_color_led_green_value = {s_ld3_green_value, s_ld2_green_value};
	assign o_color_led_blue_value = {s_ld3_blue_value, s_ld2_blue_value};
end else begin
	assign o_color_led_red_value = {s_ld3_red_value, s_ld2_red_value, s_ld1_red_value, s_ld0_red_value};
	assign o_color_led_green_value = {s_ld3_green_value, s_ld2_green_value, s_ld1_green_value, s_ld0_green_value};
	assign o_color_led_blue_value = {s_ld3_blue_value, s_ld2_blue_value, s_ld1_blue_value, s_ld0_blue_value};
end

assign o_basic_led_lumin_value = {s_ld7_basic_value, s_ld6_basic_value, s_ld5_basic_value, s_ld4_basic_value};

assign s_ld0_red_value = {s_ld0_red_pulse, 2'b11};
assign s_ld0_green_value = {s_ld0_green_pulse, 2'b11};
assign s_ld0_blue_value = {s_ld0_blue_pulse, 2'b11};

assign s_ld1_red_value = {1'b0, s_ld1_red_pulse, 1'b1};
assign s_ld1_green_value = {1'b0, s_ld1_green_pulse, 1'b1};
assign s_ld1_blue_value = {1'b0, s_ld1_blue_pulse, 1'b1};

assign s_ld2_red_value = {s_ld2_red_pulse, 2'b11};
assign s_ld2_green_value = {s_ld2_green_pulse, 2'b11};
assign s_ld2_blue_value = {s_ld2_blue_pulse, 2'b11};

assign s_ld3_red_value = {s_ld3_red_pulse, 2'b11};
assign s_ld3_green_value = {s_ld3_green_pulse, 2'b11};
assign s_ld3_blue_value = {s_ld3_blue_pulse, 2'b11};

always_ff @(posedge i_clk)
begin: p_tester_led_pulse
	if (i_srst) begin
		s_ld0_dir_pulse <= 1'b0;
		s_ld0_led_pulse <= 6'b000001;
		s_ld1_dir_pulse <= 1'b0;
		s_ld1_led_pulse <= 6'b010101;
		s_ld2_dir_pulse <= 1'b0;
		s_ld2_led_pulse <= 6'b101010;
		s_ld3_dir_pulse <= 1'b0;
		s_ld3_led_pulse <= 6'b111111;
	end else if (s_tester_led_ce) begin : if_tester_clk_enable
		// Rotate up and down a pulse value to be used for LD0
		if (s_ld0_dir_pulse)
			if (s_ld0_led_pulse == 6'b111111)
				s_ld0_dir_pulse <= 1'b0;
			else
				s_ld0_led_pulse <= s_ld0_led_pulse + 1;
		else
			if (s_ld0_led_pulse == 6'b000001)
				s_ld0_dir_pulse <= 1'b1;
			else
				s_ld0_led_pulse <= s_ld0_led_pulse - 1;
		// Rotate up and down a pulse value to be used for LD1
		if (s_ld1_dir_pulse)
			if (s_ld1_led_pulse == 6'b111111)
				s_ld1_dir_pulse <= 1'b0;
			else
				s_ld1_led_pulse <= s_ld1_led_pulse + 1;
		else
			if (s_ld1_led_pulse == 6'b000001)
				s_ld1_dir_pulse <= 1'b1;
			else
				s_ld1_led_pulse <= s_ld1_led_pulse - 1;
		// Rotate up and down a pulse value to be used for LD2
		if (s_ld2_dir_pulse)
			if (s_ld2_led_pulse == 6'b111111)
				s_ld2_dir_pulse <= 1'b0;
			else
				s_ld2_led_pulse <= s_ld2_led_pulse + 1;
		else
			if (s_ld2_led_pulse == 6'b000001)
				s_ld2_dir_pulse <= 1'b1;
			else
				s_ld2_led_pulse <= s_ld2_led_pulse - 1;
		// Rotate up and down a pulse value to be used for LD3
		if (s_ld3_dir_pulse)
			if (s_ld3_led_pulse == 6'b111111)
				s_ld3_dir_pulse <= 1'b0;
			else
				s_ld3_led_pulse <= s_ld3_led_pulse + 1;
		else
			if (s_ld3_led_pulse == 6'b000001)
				s_ld3_dir_pulse <= 1'b1;
			else
				s_ld3_led_pulse <= s_ld3_led_pulse - 1;
	end : if_tester_clk_enable
end : p_tester_led_pulse

always_ff @(posedge i_clk)
begin: p_tester_led_display
	if (i_active_init_display) begin
		// LED 0 will be red when tester is initializing.
		s_ld0_red_pulse <= s_ld0_led_pulse;
		s_ld0_green_pulse <= 6'b000001;
		s_ld0_blue_pulse <= 6'b000001;
	end else if (i_active_run_display) begin
		// LED 0 will be green when tester is running.
		s_ld0_red_pulse <= 6'b000001;
		s_ld0_green_pulse <= s_ld0_led_pulse;
		s_ld0_blue_pulse <= 6'b000001;
	end else begin
		// LED 0 will be blue when tester is not working at all.
		s_ld0_red_pulse <= 6'b000001;
		s_ld0_green_pulse <= 6'b000001;
		s_ld0_blue_pulse <= s_ld0_led_pulse;
	end

	// LED 1 will be red when tester is not working at all.
	// LED 1 will be white when tester is measuring continuously.
	// LED 1 will be purple when tester is only detecting motion toggle.
	if (i_mode_is_measur_aux) begin
		s_ld1_red_pulse <= s_ld1_led_pulse;
		s_ld1_green_pulse <= s_ld1_led_pulse;
		s_ld1_blue_pulse <= s_ld1_led_pulse;
	end else if (i_mode_is_linked_aux) begin
		s_ld1_red_pulse <= s_ld1_led_pulse;
		s_ld1_green_pulse <= 6'b000001;
		s_ld1_blue_pulse <= s_ld1_led_pulse;
	end else begin
		s_ld1_red_pulse <= s_ld1_led_pulse;
		s_ld1_green_pulse <= 6'b000001;
		s_ld1_blue_pulse <= 6'b000001;
	end

	// LED 2 is Red when no Activity detect, Green when Activity detect.
	if (i_acl2_activity_stretched & i_mode_is_linked_aux) begin
		s_ld2_red_pulse <= 6'b000001;
		s_ld2_green_pulse <= 6'b111111;
		s_ld2_blue_pulse <= 6'b000001;
	end else begin
		s_ld2_red_pulse <= s_ld2_led_pulse;
		s_ld2_green_pulse <= {6'b0000, s_ld2_led_pulse[1-:2]};
		s_ld2_blue_pulse <= 6'b000000;
	end

	// LED 3 is Red when no Inactivity detect, Green when Inactivity detect.
	if (i_acl2_inactivity_stretched & i_mode_is_linked_aux) begin
		s_ld3_red_pulse <= 6'b000001;
		s_ld3_green_pulse <= 6'b111111;
		s_ld3_blue_pulse <= 6'b000001;
	end else begin
		s_ld3_red_pulse <= s_ld3_led_pulse;
		s_ld3_green_pulse <= {6'b0000, s_ld3_led_pulse[1-:2]};
		s_ld3_blue_pulse <= 6'b000000;
	end

	// LED4 is AWAKE status from the status register
	if (i_acl2_awake_status)
		s_ld4_basic_value <= 8'hFF;
	else
		s_ld4_basic_value <= 8'h00;

	// LED 5 is unused at this time.
	s_ld5_basic_value <= 8'h00;

	// LED 6, LED 7, indicate the debounced switch positions.
	if (i_sw0_selected)
		s_ld6_basic_value <= 8'hFF;
	else
		s_ld6_basic_value <= 8'h00;

	if (i_sw1_selected)
		s_ld7_basic_value <= 8'hFF;
	else
		s_ld7_basic_value <= 8'h00;

end : p_tester_led_display

endmodule : led_palette_pulser
//------------------------------------------------------------------------------
`end_keywords
