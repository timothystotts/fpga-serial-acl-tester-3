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
-- \file led_pwm_driver.v
--
-- \brief A 24-bit palette interface to three-filament discrete color LEDs.
--
-- \description A color-mixing solution for color LEDs.
------------------------------------------------------------------------------*/
//Generate loops for PWMs-------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module led_pwm_driver(i_clk, i_srst, i_color_led_red_value, i_color_led_green_value,
	i_color_led_blue_value, i_basic_led_lumin_value,
	eo_color_leds_r, eo_color_leds_g, eo_color_leds_b, eo_basic_leds_l);

parameter integer parm_color_led_count = 4;
parameter integer parm_basic_led_count = 4;
parameter integer parm_FCLK = 40_000_000;
parameter integer parm_pwm_period_milliseconds = 10;

localparam integer c_color_value_upper = 8 * parm_color_led_count - 1;
localparam integer c_basic_value_upper = 8 * parm_basic_led_count - 1;
localparam integer c_color_count_upper = parm_color_led_count - 1;
localparam integer c_basic_count_upper = parm_basic_led_count - 1;

input wire i_clk;
input wire i_srst;
input wire [c_color_value_upper:0] i_color_led_red_value;
input wire [c_color_value_upper:0] i_color_led_green_value;
input wire [c_color_value_upper:0] i_color_led_blue_value;
input wire [c_basic_value_upper:0] i_basic_led_lumin_value;

output reg [c_color_count_upper:0] eo_color_leds_r;
output reg [c_color_count_upper:0] eo_color_leds_g;
output reg [c_color_count_upper:0] eo_color_leds_b;
output reg [c_basic_count_upper:0] eo_basic_leds_l;

//Part 2: Declarations----------------------------------------------------------
localparam integer c_pwm_period_ms = parm_FCLK / 1000 * parm_pwm_period_milliseconds;
localparam integer c_pwm_color_max_duty_cycle = c_pwm_period_ms / 10 * 8;
localparam integer c_pwm_color_max_duty_cycle_ratioed = c_pwm_color_max_duty_cycle / 255;
localparam integer c_pwm_basic_max_duty_cycle = c_pwm_period_ms / 10 * 9;
localparam integer c_pwm_basic_max_duty_cycle_ratioed = c_pwm_basic_max_duty_cycle / 255;
localparam c_filament_on_value = 1'b1;
localparam c_filament_off_value = 1'b0;

//Part 3: Statements------------------------------------------------------------
generate
	genvar redidx;
	for (redidx = 0; redidx < parm_color_led_count; redidx = redidx + 1) begin: redloop
		integer s_color_red_pwm_period_count;
		integer s_color_red_pwm_duty_cycles;
		integer s_color_red_pwm_duty_cycles_1;
		integer s_color_red_pwm_duty_cycles_2;
        reg [7:0] s_color_led_red_value_0;
        
		always @(posedge i_clk)
		begin: p_operate_color_red_pwm
			if (i_srst) begin
				eo_color_leds_r[redidx] <= c_filament_off_value;
				s_color_red_pwm_period_count <= c_pwm_period_ms - 1;
				s_color_red_pwm_duty_cycles <= 0;
				s_color_led_red_value_0 <= 8'h00;
				s_color_red_pwm_duty_cycles_1 <= 0;
				s_color_red_pwm_duty_cycles_2 <= 0;

			end else begin
				if (s_color_red_pwm_period_count > 0) begin
					if (s_color_red_pwm_period_count < s_color_red_pwm_duty_cycles)
						eo_color_leds_r[redidx] <= c_filament_on_value;
					else
						eo_color_leds_r[redidx] <= c_filament_off_value;
				
					s_color_red_pwm_period_count <= s_color_red_pwm_period_count - 1;
				end else begin
					eo_color_leds_r[redidx] <= c_filament_on_value;
					s_color_red_pwm_period_count <= c_pwm_period_ms - 1;
					
					// Register the DSP48E1 output
					s_color_red_pwm_duty_cycles <= s_color_red_pwm_duty_cycles_2;
				end
				
				// Register inferred DSP48E1 Register B
				s_color_led_red_value_0 <= i_color_led_red_value[(redidx * 8 + 7)-:8];
				
				// Register inferred DSP48E1 Register A or D
				// Register inferred DSP48E1 Multiply
				s_color_red_pwm_duty_cycles_1 <= c_pwm_color_max_duty_cycle_ratioed * s_color_led_red_value_0;
				
				// Register the inferred DSP48E1 output P
				s_color_red_pwm_duty_cycles_2 <= s_color_red_pwm_duty_cycles_1;
			end
		end
	end
endgenerate

generate
	genvar greenidx;
	for (greenidx = 0; greenidx < parm_color_led_count; greenidx = greenidx + 1) begin: greenloop
		integer s_color_green_pwm_period_count;
		integer s_color_green_pwm_duty_cycles;
		integer s_color_green_pwm_duty_cycles_1;
		integer s_color_green_pwm_duty_cycles_2;
        reg [7:0] s_color_led_green_value_0;
        
		always @(posedge i_clk)
		begin: p_operate_color_green_pwm
			if (i_srst) begin
				eo_color_leds_g[greenidx] <= c_filament_off_value;
				s_color_green_pwm_period_count <= c_pwm_period_ms - 1;
				s_color_green_pwm_duty_cycles <= 0;
				s_color_led_green_value_0 <= 8'h00;
				s_color_green_pwm_duty_cycles_1 <= 0;
				s_color_green_pwm_duty_cycles_2 <= 0;

			end else begin
				if (s_color_green_pwm_period_count > 0) begin
					if (s_color_green_pwm_period_count < s_color_green_pwm_duty_cycles)
						eo_color_leds_g[greenidx] <= c_filament_on_value;
					else
						eo_color_leds_g[greenidx] <= c_filament_off_value;
				
					s_color_green_pwm_period_count <= s_color_green_pwm_period_count - 1;
				end else begin
					eo_color_leds_g[greenidx] <= c_filament_on_value;
					s_color_green_pwm_period_count <= c_pwm_period_ms - 1;
					
					// Register the DSP48E1 output
					s_color_green_pwm_duty_cycles <= s_color_green_pwm_duty_cycles_2;
				end
				
				// Register inferred DSP48E1 Register B
				s_color_led_green_value_0 <= i_color_led_green_value[(greenidx * 8 + 7)-:8];
				
				// Register inferred DSP48E1 Register A or D
				// Register inferred DSP48E1 Multiply
				s_color_green_pwm_duty_cycles_1 <= c_pwm_color_max_duty_cycle_ratioed * s_color_led_green_value_0;
				
				// Register the inferred DSP48E1 output P
				s_color_green_pwm_duty_cycles_2 <= s_color_green_pwm_duty_cycles_1;
			end
		end
	end
endgenerate

generate
	genvar blueidx;
	for (blueidx = 0; blueidx < parm_color_led_count; blueidx = blueidx + 1) begin: blueloop
		integer s_color_blue_pwm_period_count;
		integer s_color_blue_pwm_duty_cycles;
		integer s_color_blue_pwm_duty_cycles_1;
		integer s_color_blue_pwm_duty_cycles_2;
        reg [7:0] s_color_led_blue_value_0;
        
		always @(posedge i_clk)
		begin: p_operate_color_blue_pwm
			if (i_srst) begin
				eo_color_leds_b[blueidx] <= c_filament_off_value;
				s_color_blue_pwm_period_count <= c_pwm_period_ms - 1;
				s_color_blue_pwm_duty_cycles <= 0;
				s_color_led_blue_value_0 <= 8'h00;
				s_color_blue_pwm_duty_cycles_1 <= 0;
				s_color_blue_pwm_duty_cycles_2 <= 0;

			end else begin
				if (s_color_blue_pwm_period_count > 0) begin
					if (s_color_blue_pwm_period_count < s_color_blue_pwm_duty_cycles)
						eo_color_leds_b[blueidx] <= c_filament_on_value;
					else
						eo_color_leds_b[blueidx] <= c_filament_off_value;
				
					s_color_blue_pwm_period_count <= s_color_blue_pwm_period_count - 1;
				end else begin
					eo_color_leds_b[blueidx] <= c_filament_on_value;
					s_color_blue_pwm_period_count <= c_pwm_period_ms - 1;
					
					// Register the DSP48E1 output
					s_color_blue_pwm_duty_cycles <= s_color_blue_pwm_duty_cycles_2;
				end
				
				// Register inferred DSP48E1 Register B
				s_color_led_blue_value_0 <= i_color_led_blue_value[(blueidx * 8 + 7)-:8];
				
				// Register inferred DSP48E1 Register A or D
				// Register inferred DSP48E1: Multiply
				s_color_blue_pwm_duty_cycles_1 <= c_pwm_color_max_duty_cycle_ratioed * s_color_led_blue_value_0;
				
				// Register the inferred DSP48E1 output P
				s_color_blue_pwm_duty_cycles_2 <= s_color_blue_pwm_duty_cycles_1;
			end
		end
	end
endgenerate

generate
	genvar basicidx;
	for (basicidx = 0; basicidx < parm_basic_led_count; basicidx = basicidx + 1) begin: basicloop
		integer s_basic_lumin_pwm_period_count;
		integer s_basic_lumin_pwm_duty_cycles;
		integer s_basic_lumin_pwm_duty_cycles_1;
		integer s_basic_lumin_pwm_duty_cycles_2;
        reg [7:0] s_basic_led_lumin_value_0;
        
		always @(posedge i_clk)
		begin: p_operate_basic_lumin_pwm
			if (i_srst) begin
				eo_basic_leds_l[basicidx] <= c_filament_off_value;
				s_basic_lumin_pwm_period_count <= c_pwm_period_ms - 1;
				s_basic_lumin_pwm_duty_cycles <= 0;
				s_basic_led_lumin_value_0 <= 8'h00;
				s_basic_lumin_pwm_duty_cycles_1 <= 0;
				s_basic_lumin_pwm_duty_cycles_2 <= 0;

			end else begin
				if (s_basic_lumin_pwm_period_count > 0) begin
					if (s_basic_lumin_pwm_period_count < s_basic_lumin_pwm_duty_cycles)
						eo_basic_leds_l[basicidx] <= c_filament_on_value;
					else
						eo_basic_leds_l[basicidx] <= c_filament_off_value;
				
					s_basic_lumin_pwm_period_count <= s_basic_lumin_pwm_period_count - 1;
				end else begin
					eo_basic_leds_l[basicidx] <= c_filament_on_value;
					s_basic_lumin_pwm_period_count <= c_pwm_period_ms - 1;
					
					// Register the DSP48E1 output
					s_basic_lumin_pwm_duty_cycles <= s_basic_lumin_pwm_duty_cycles_2;
				end
				
				// Register inferred DSP48E1 Register B
				s_basic_led_lumin_value_0 <= i_basic_led_lumin_value[(basicidx * 8 + 7)-:8];
				
				// Register inferred DSP48E1 Register A or D
				// Register inferred DSP48E1 Multiply
				s_basic_lumin_pwm_duty_cycles_1 <= c_pwm_basic_max_duty_cycle_ratioed * s_basic_led_lumin_value_0;
				
				// Register the output P
				s_basic_lumin_pwm_duty_cycles_2 <= s_basic_lumin_pwm_duty_cycles_1;
			end
		end
	end
endgenerate

endmodule
//------------------------------------------------------------------------------
