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
-- \file acl_tester_fsm.v
--
-- \brief A simple FSM to control the execution of the ADXL362 accelerometer
-- testing.
------------------------------------------------------------------------------*/
//Recursive Moore Machine-------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module acl_tester_fsm(i_clk_20mhz, i_rst_20mhz, i_acl_command_ready,
	i_switches_debounced, o_reading_inactive, o_active_init_display,
	o_active_run_display, o_mode_is_measur, o_mode_is_linked,
	o_acl_cmd_init_measur_mode, o_acl_cmd_start_measur_mode,
	o_acl_cmd_init_linked_mode, o_acl_cmd_start_linked_mode,
	o_acl_cmd_soft_reset);

input wire i_clk_20mhz;
input wire i_rst_20mhz;

input wire i_acl_command_ready;
input wire [3:0] i_switches_debounced;

output reg o_reading_inactive;
output reg o_active_init_display;
output reg o_active_run_display;
output wire o_mode_is_measur;
output wire o_mode_is_linked;
output reg o_acl_cmd_init_measur_mode;
output reg o_acl_cmd_start_measur_mode;
output reg o_acl_cmd_init_linked_mode;
output reg o_acl_cmd_start_linked_mode;
output reg o_acl_cmd_soft_reset;

//Part 2: Declarations----------------------------------------------------------
/* Tester FSM state declarations */
`define c_tester_state_bits 4
localparam [(`c_tester_state_bits - 1):0] ST_0 = 0;
localparam [(`c_tester_state_bits - 1):0] ST_1 = 1;
localparam [(`c_tester_state_bits - 1):0] ST_2 = 2;
localparam [(`c_tester_state_bits - 1):0] ST_3 = 3;
localparam [(`c_tester_state_bits - 1):0] ST_4 = 4;
localparam [(`c_tester_state_bits - 1):0] ST_5 = 5;
localparam [(`c_tester_state_bits - 1):0] ST_6 = 6;
localparam [(`c_tester_state_bits - 1):0] ST_7 = 7;
localparam [(`c_tester_state_bits - 1):0] ST_8 = 8;
localparam [(`c_tester_state_bits - 1):0] ST_9 = 9;
localparam [(`c_tester_state_bits - 1):0] ST_A = 10;
localparam [(`c_tester_state_bits - 1):0] ST_B = 11;

reg [(`c_tester_state_bits - 1):0] s_tester_pr_state = ST_0;
reg [(`c_tester_state_bits - 1):0] s_tester_nx_state = ST_0;

// Tester FSM auxiliary registers that translate to LED color display.
reg s_mode_is_measur_val;
reg s_mode_is_measur_aux;
reg s_mode_is_linked_val;
reg s_mode_is_linked_aux;

//Part 3: Statements------------------------------------------------------------
// State auxiliary outputs
assign o_mode_is_linked = s_mode_is_linked_aux;
assign o_mode_is_measur = s_mode_is_measur_aux;

/* The top-level Tester FSM State Transition register on the system clock,
   for state and auxiliary of the FSM that sends operation mode commands to
   the PMOD ACL2 custom driver. */
always @(posedge i_clk_20mhz)
begin: p_tester_fsm_state_aux
	if (i_rst_20mhz) begin
		s_tester_pr_state <= ST_0;

		s_mode_is_measur_aux <= 1'b0;
		s_mode_is_linked_aux <= 1'b0;
	end else begin
		s_tester_pr_state <= s_tester_nx_state;

		s_mode_is_measur_aux <= s_mode_is_measur_val;
		s_mode_is_linked_aux <= s_mode_is_linked_val;
	end
end

/* Tester FSM Combinatorial logic for initializing and starting PMOD ACL2
   according to the position of Switch 0 and the position of Switch 1. If
   Switch 0 and Not Switch 1, then Mode Measurement is executed. If Switch 1
   and Not Switch 0, then Mode Linked is executed. */
always @(s_tester_pr_state, i_acl_command_ready,
	i_switches_debounced,
	s_mode_is_measur_aux, s_mode_is_linked_aux)
begin: p_tester_fsm_comb
	case (s_tester_pr_state)
		ST_1: begin /* Step one to command initialize the ACL2 to measurement mode */
			o_reading_inactive = 1'b0;
			o_acl_cmd_init_measur_mode = 1'b1;
			o_acl_cmd_init_linked_mode = 1'b0;
			o_acl_cmd_start_measur_mode = 1'b0;
			o_acl_cmd_start_linked_mode = 1'b0;
			o_acl_cmd_soft_reset = 1'b0;
			o_active_init_display = 1'b1;
			o_active_run_display = 1'b0;
			s_mode_is_measur_val = 1'b1;
			s_mode_is_linked_val = 1'b0;

			if (i_acl_command_ready) s_tester_nx_state = ST_1;
			else s_tester_nx_state = ST_2;
		end
		ST_2: begin /* Step two to wait for ACL2 to start its MM initialization */
			o_reading_inactive = 1'b0;
			o_acl_cmd_init_measur_mode = 1'b0;
			o_acl_cmd_init_linked_mode = 1'b0;
			o_acl_cmd_start_measur_mode = 1'b0;
			o_acl_cmd_start_linked_mode = 1'b0;
			o_acl_cmd_soft_reset = 1'b0;
			o_active_init_display = 1'b1;
			o_active_run_display = 1'b0;
			s_mode_is_measur_val = s_mode_is_measur_aux;
			s_mode_is_linked_val = s_mode_is_linked_aux;
			
			if (! i_acl_command_ready) s_tester_nx_state = ST_2;
			else s_tester_nx_state = ST_3;
		end
		ST_3: begin /* Step three to command start the ACL2 to measurement mode */
			o_reading_inactive = 1'b0;
			o_acl_cmd_init_measur_mode = 1'b0;
			o_acl_cmd_init_linked_mode = 1'b0;
			o_acl_cmd_start_measur_mode = 1'b1;
			o_acl_cmd_start_linked_mode = 1'b0;
			o_acl_cmd_soft_reset = 1'b0;
			o_active_init_display = 1'b1;
			o_active_run_display = 1'b0;
			s_mode_is_measur_val = s_mode_is_measur_aux;
			s_mode_is_linked_val = s_mode_is_linked_aux;

			if (i_acl_command_ready) s_tester_nx_state = ST_3;
			else s_tester_nx_state = ST_4;
		end
		ST_4: begin /* Step four to stop issuing commands and transition to IDLE
					   (place holder for other steps) */
			o_reading_inactive = 1'b0;
			o_acl_cmd_init_measur_mode = 1'b0;
			o_acl_cmd_init_linked_mode = 1'b0;
			o_acl_cmd_start_measur_mode = 1'b0;
			o_acl_cmd_start_linked_mode = 1'b0;
			o_acl_cmd_soft_reset = 1'b0;
			o_active_init_display = 1'b1;
			o_active_run_display = 1'b0;
			s_mode_is_measur_val = s_mode_is_measur_aux;
			s_mode_is_linked_val = s_mode_is_linked_aux;
			
			s_tester_nx_state = ST_9;
		end
		ST_5: begin /* Step one to command initialize the ACL2 to linked mode */
			o_reading_inactive = 1'b0;
			o_acl_cmd_init_measur_mode = 1'b0;
			o_acl_cmd_init_linked_mode = 1'b1;
			o_acl_cmd_start_measur_mode = 1'b0;
			o_acl_cmd_start_linked_mode = 1'b0;
			o_acl_cmd_soft_reset = 1'b0;
			o_active_init_display = 1'b1;
			o_active_run_display = 1'b0;
			s_mode_is_measur_val = 1'b0;
			s_mode_is_linked_val = 1'b1;

			if (i_acl_command_ready) s_tester_nx_state = ST_5;
			else s_tester_nx_state = ST_6;
		end
		ST_6: begin /* Step two to wait for ACL2 to start its LM initialization */
			o_reading_inactive = 1'b0;
			o_acl_cmd_init_measur_mode = 1'b0;
			o_acl_cmd_init_linked_mode = 1'b0;
			o_acl_cmd_start_measur_mode = 1'b0;
			o_acl_cmd_start_linked_mode = 1'b0;
			o_acl_cmd_soft_reset = 1'b0;
			o_active_init_display = 1'b1;
			o_active_run_display = 1'b0;
			s_mode_is_measur_val = s_mode_is_measur_aux;
			s_mode_is_linked_val = s_mode_is_linked_aux;
			
			if (! i_acl_command_ready) s_tester_nx_state = ST_6;
			else s_tester_nx_state = ST_7;
		end
		ST_7: begin /* Step three to command start the ACL2 to linked mode */
			o_reading_inactive = 1'b0;
			o_acl_cmd_init_measur_mode = 1'b0;
			o_acl_cmd_init_linked_mode = 1'b0;
			o_acl_cmd_start_measur_mode = 1'b0;
			o_acl_cmd_start_linked_mode = 1'b1;
			o_acl_cmd_soft_reset = 1'b0;
			o_active_init_display = 1'b1;
			o_active_run_display = 1'b0;
			s_mode_is_measur_val = s_mode_is_measur_aux;
			s_mode_is_linked_val = s_mode_is_linked_aux;

			if (i_acl_command_ready) s_tester_nx_state = ST_7;
			else s_tester_nx_state = ST_8;
		end
		ST_8: begin /* Step four to stop issuing commands and transition to IDLE
					   (place holder for other steps) */
			o_reading_inactive = 1'b0;
			o_acl_cmd_init_measur_mode = 1'b0;
			o_acl_cmd_init_linked_mode = 1'b0;
			o_acl_cmd_start_measur_mode = 1'b0;
			o_acl_cmd_start_linked_mode = 1'b0;
			o_acl_cmd_soft_reset = 1'b0;
			o_active_init_display = 1'b1;
			o_active_run_display = 1'b0;
			s_mode_is_measur_val = s_mode_is_measur_aux;
			s_mode_is_linked_val = s_mode_is_linked_aux;
			
			s_tester_nx_state = ST_9;
		end
		ST_9: begin /* State nine is RUNNING IDLE and waits for switches 0,1
					   to entera equal an non-exclusive state to then transition
					   to State A which in turn will reset the PMOD ACL2 and wait
					   for an exclusive command on the switches 0,1. */
			o_reading_inactive = 1'b0;
			o_acl_cmd_init_measur_mode = 1'b0;
			o_acl_cmd_init_linked_mode = 1'b0;
			o_acl_cmd_start_measur_mode = 1'b0;
			o_acl_cmd_start_linked_mode = 1'b0;
			o_acl_cmd_soft_reset = 1'b0;
			o_active_init_display = 1'b0;
			o_active_run_display = 1'b1;
			s_mode_is_measur_val = s_mode_is_measur_aux;
			s_mode_is_linked_val = s_mode_is_linked_aux;

			if (i_switches_debounced == 4'b0000)
				s_tester_nx_state = ST_A;
			else
				s_tester_nx_state = ST_9;
		end
		ST_A: begin /* Step A to issue the Soft Reset command to the PMOD ACL2
					   Then transition to Step Zero for INIT IDLE and waiting
					   for exclusive switch position. */
			o_reading_inactive = 1'b0;
			o_acl_cmd_init_measur_mode = 1'b0;
			o_acl_cmd_init_linked_mode = 1'b0;
			o_acl_cmd_start_measur_mode = 1'b0;
			o_acl_cmd_start_linked_mode = 1'b0;
			o_acl_cmd_soft_reset = 1'b1; /* acts as a level interrupt instead of command */
			o_active_init_display = 1'b0;
			o_active_run_display = 1'b0;
			s_mode_is_measur_val = 1'b0;
			s_mode_is_linked_val = 1'b0;

			if (i_acl_command_ready) s_tester_nx_state = ST_0;
			else s_tester_nx_state = ST_A;
		end

		default: begin // ST_0
					   /* Step Zero is INIT IDLE, waiting for exclusive switch
						  position to then transition to INIT Measure Mode or
						  INIT Linked Mode. */
			o_reading_inactive = 1'b1;
			o_acl_cmd_init_measur_mode = 1'b0;
			o_acl_cmd_init_linked_mode = 1'b0;
			o_acl_cmd_start_measur_mode = 1'b0;
			o_acl_cmd_start_linked_mode = 1'b0;
			o_acl_cmd_soft_reset = 1'b0;
			o_active_init_display = 1'b0;
			o_active_run_display = 1'b0;
			s_mode_is_measur_val = s_mode_is_measur_aux;
			s_mode_is_linked_val = s_mode_is_linked_aux;

			if (i_acl_command_ready)
				if (i_switches_debounced == 4'b0001)
					s_tester_nx_state = ST_1;
				else if (i_switches_debounced == 4'b0010)
					s_tester_nx_state = ST_5;
				else
					s_tester_nx_state = ST_0;
			else s_tester_nx_state = ST_0;
		end
	endcase
end

endmodule
//------------------------------------------------------------------------------
