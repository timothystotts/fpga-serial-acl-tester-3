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
-- \file lcd_text_feed.v
--
-- \brief A timed FSM to feed display updates to a two-line LCD.
------------------------------------------------------------------------------*/
//Recursive Moore Machine-------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module lcd_text_feed(i_clk_20mhz, i_rst_20mhz, i_ce_2_5mhz,
	i_lcd_command_ready, o_lcd_wr_clear_display, o_lcd_wr_text_line1,
	o_lcd_wr_text_line2, o_lcd_feed_is_idle);

parameter integer parm_fast_simulation = 0;

input wire i_clk_20mhz;
input wire i_rst_20mhz;
input wire i_ce_2_5mhz;
input wire i_lcd_command_ready;

output reg o_lcd_wr_clear_display;
output reg o_lcd_wr_text_line1;
output reg o_lcd_wr_text_line2;
output wire o_lcd_feed_is_idle;

//Part 2: Declarations----------------------------------------------------------
/* Connections and variables for instance of the PMOD CLS SPI SOLO driver. */
`define c_lcd_update_fsm_bits 4
localparam [(`c_lcd_update_fsm_bits - 1):0] ST_LCD_PAUSE = 0;
localparam [(`c_lcd_update_fsm_bits - 1):0] ST_LCD_CLEAR_RUN = 1;
localparam [(`c_lcd_update_fsm_bits - 1):0] ST_LCD_CLEAR_DLY = 2;
localparam [(`c_lcd_update_fsm_bits - 1):0] ST_LCD_CLEAR_WAIT = 3;
localparam [(`c_lcd_update_fsm_bits - 1):0] ST_LCD_LINE1_RUN = 4;
localparam [(`c_lcd_update_fsm_bits - 1):0] ST_LCD_LINE1_DLY = 5;
localparam [(`c_lcd_update_fsm_bits - 1):0] ST_LCD_LINE1_WAIT = 6;
localparam [(`c_lcd_update_fsm_bits - 1):0] ST_LCD_LINE2_RUN = 7;
localparam [(`c_lcd_update_fsm_bits - 1):0] ST_LCD_LINE2_DLY = 8;

reg [(`c_lcd_update_fsm_bits - 1):0] s_lcd_upd_pr_state;
reg [(`c_lcd_update_fsm_bits - 1):0] s_lcd_upd_nx_state;

/* Timer steps for the continuous refresh of the PMOD CLS display:
   Clear Display
   Wait 1.0 milliseconds
   Write Line 1
   Wait 1.0 milliseconds
   Write Line 2
   Wait 0.2 seconds
   Repeat the above. */
`define c_lcd_update_timer_bits 24
/* The sub-second refresh is actually 1/5 of a second to have a 5 Hz refresh,
   approximately. If \ref parm_fast_simulation is defined, then tne once
   second refresh is actually 1/100 of a second to have a 100 Hz refresh
   for waveform viewing. */
localparam [(`c_lcd_update_timer_bits - 1):0] c_i_one_ms =
	parm_fast_simulation ? 2500 : 2500;
localparam [(`c_lcd_update_timer_bits - 1):0] c_i_subsecond =
	parm_fast_simulation ? (2500000 / 20 - (2 * c_i_one_ms)) : (2500000 / 5 - (2 * c_i_one_ms));
localparam [(`c_lcd_update_timer_bits - 1):0] c_i_max = c_i_subsecond;

reg [(`c_lcd_update_timer_bits - 1):0] s_i;

//Part 3: Statements------------------------------------------------------------
/* Timer (strategy #1) for timing the PMOD CLS display update */
always @(posedge i_clk_20mhz)
begin: p_fsm_timer_run_display_update
	if (i_rst_20mhz) s_i <= 0;
	else
		if (i_ce_2_5mhz)
			if (s_lcd_upd_pr_state != s_lcd_upd_nx_state) begin
				s_i <= 0;
			end else if (s_i != c_i_max) begin
				s_i <= s_i + 1;
			end
end

/* FSM state transition for timing the PMOD CLS display udpate */
always @(posedge i_clk_20mhz)
begin: p_fsm_state_run_display_update
	if (i_rst_20mhz) s_lcd_upd_pr_state <= ST_LCD_PAUSE;
	else 
		if (i_ce_2_5mhz)
			s_lcd_upd_pr_state <= s_lcd_upd_nx_state;
end

/* FSM combinatorial logic for timing the PMOD CLS display udpate */
always @(s_lcd_upd_pr_state, i_lcd_command_ready, s_i)
begin: p_fsm_comb_run_display_update
	case (s_lcd_upd_pr_state)
		ST_LCD_CLEAR_RUN: begin /* Issue a clear command and wait for
								   the LCD driver to acknowledge a
								   command in progress. */
			o_lcd_wr_clear_display = 1'b1;
			o_lcd_wr_text_line1 = 1'b0;
			o_lcd_wr_text_line2 = 1'b0;

			if (! i_lcd_command_ready) s_lcd_upd_nx_state = ST_LCD_CLEAR_DLY;
			else s_lcd_upd_nx_state = ST_LCD_CLEAR_RUN;
		end
		ST_LCD_CLEAR_DLY: begin /* Now that the Clear command is running,
								   wait for one millisecond. */
			o_lcd_wr_clear_display = 1'b0;
			o_lcd_wr_text_line1 = 1'b0;
			o_lcd_wr_text_line2 = 1'b0;

			if (s_i == c_i_one_ms - 1) s_lcd_upd_nx_state = ST_LCD_CLEAR_WAIT;
			else s_lcd_upd_nx_state = ST_LCD_CLEAR_DLY;
		end			
		ST_LCD_CLEAR_WAIT: begin /* Advance to writing LINE 1 when the
								   LCD driver is ready for input. */
			o_lcd_wr_clear_display = 1'b0;
			o_lcd_wr_text_line1 = 1'b0;
			o_lcd_wr_text_line2 = 1'b0;

			if (i_lcd_command_ready) s_lcd_upd_nx_state = ST_LCD_LINE1_RUN;
			else s_lcd_upd_nx_state = ST_LCD_CLEAR_WAIT;
		end			
		ST_LCD_LINE1_RUN: begin /* Issue a write Line 1 command and wait for
								   the LCD driver to acknowledge a
								   command in progress. */
			o_lcd_wr_clear_display = 1'b0;
			o_lcd_wr_text_line1 = 1'b1;
			o_lcd_wr_text_line2 = 1'b0;

			if (! i_lcd_command_ready) s_lcd_upd_nx_state = ST_LCD_LINE1_DLY;
			else s_lcd_upd_nx_state = ST_LCD_LINE1_RUN;
		end
		ST_LCD_LINE1_DLY: begin /* Now that the write Line 1 command is running,
								   wait for one millisecond. */
			o_lcd_wr_clear_display = 1'b0;
			o_lcd_wr_text_line1 = 1'b0;
			o_lcd_wr_text_line2 = 1'b0;

			if (s_i == c_i_one_ms - 1) s_lcd_upd_nx_state = ST_LCD_LINE1_WAIT;
			else s_lcd_upd_nx_state = ST_LCD_LINE1_DLY;
		end
		ST_LCD_LINE1_WAIT: begin /* Advance to writing LINE 2 when the
								   LCD driver is ready for input. */
			o_lcd_wr_clear_display = 1'b0;
			o_lcd_wr_text_line1 = 1'b0;
			o_lcd_wr_text_line2 = 1'b0;

			if (i_lcd_command_ready) s_lcd_upd_nx_state = ST_LCD_LINE2_RUN;
			else s_lcd_upd_nx_state = ST_LCD_LINE1_WAIT;
		end			
		ST_LCD_LINE2_RUN: begin /* Issue a write Line 2 command and wait for
								   the LCD driver to acknowledge a
								   command in progress. */
			o_lcd_wr_clear_display = 1'b0;
			o_lcd_wr_text_line1 = 1'b0;
			o_lcd_wr_text_line2 = 1'b1;

			if (! i_lcd_command_ready) s_lcd_upd_nx_state = ST_LCD_LINE2_DLY;
			else s_lcd_upd_nx_state = ST_LCD_LINE2_RUN;
		end
		ST_LCD_LINE2_DLY: begin /* Now that the write Line 2 command is running,
								   wait for one millisecond. */
			o_lcd_wr_clear_display = 1'b0;
			o_lcd_wr_text_line1 = 1'b0;
			o_lcd_wr_text_line2 = 1'b0;

			if (s_i == c_i_subsecond - 1) s_lcd_upd_nx_state = ST_LCD_PAUSE;
			else s_lcd_upd_nx_state = ST_LCD_LINE2_DLY;
		end
		default: begin // ST_LCD_PAUSE
					   /* Step PAUSE, wait until display ready to write again */
			o_lcd_wr_clear_display = 1'b0;
			o_lcd_wr_text_line1 = 1'b0;
			o_lcd_wr_text_line2 = 1'b0;

			if (i_lcd_command_ready) s_lcd_upd_nx_state = ST_LCD_CLEAR_RUN;
			else s_lcd_upd_nx_state = ST_LCD_PAUSE;
		end
	endcase
end

// Indicate when the FSM is idle
assign o_lcd_feed_is_idle = (s_lcd_upd_pr_state == ST_LCD_LINE2_DLY) ? 1'b1 : 1'b0;

endmodule
//------------------------------------------------------------------------------

