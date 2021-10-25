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
-- \file pmod_acl2_custom_driver.v
--
-- \brief A wrapper for the single Chip Select, Standard SPI modules
--        \ref pmod_acl2_stand_spi_solo and \ref pmod_generic_spi_solo ,
--        implementing a custom multi-mode operation of the PMOD ACL2 by
--        Digilent Inc with SPI bus communication and two GPIO level interrupts
--        input from the PMOD ACL2.
------------------------------------------------------------------------------*/
//------------------------------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module pmod_acl2_custom_driver (
	/* Clock and reset, with clock at 4 times the frequency of the SPI bus */
	i_clk_20mhz, i_rst_20mhz,
	/* Outputs and inputs from the single SPI peripheral */
	eo_sck_t, eo_sck_o, eo_csn_t, eo_csn_o, eo_copi_t, eo_copi_o,
	ei_cipo,
	ei_int1, ei_int2,
	/* Command ready indication and five possible commands to the driver */
	o_command_ready,
	i_cmd_init_linked_mode,
	i_cmd_start_linked_mode,
	i_cmd_init_measur_mode,
	i_cmd_start_measur_mode,
	i_cmd_soft_reset_acl2,
	/* Output of the measurements in a single vector, plus a valid pulse */
	o_data_3axis_temp,
	o_data_valid,
	/* Output of the most recently read single byte status register,
	   without a valid pualse. */
	o_reg_status,
	/* Debounced buttons input */
	i_btn_deb,
	/* Active and Inactive preset enumeration value */
	o_enum_active,
	o_enum_inactive);

/* Disable or enable fast FSM delays for simulation instead of impelementation. */
parameter integer parm_fast_simulation = 0;
/* Actual frequency in Hz of \ref i_clk_20mhz */
parameter integer FCLK = 20000000;
/* Ratio of i_ext_spi_clk_x to SPI sck bus output. */
parameter parm_ext_spi_clk_ratio = 4;
/* LOG2 of the TX FIFO max count */
parameter parm_tx_len_bits = 11;
/* LOG2 of max Wait Cycles count between end of TX and start of RX */
parameter parm_wait_cyc_bits = 2;
/* LOG2 of the RX FIFO max count */
parameter parm_rx_len_bits = 11;

input wire i_clk_20mhz;
input wire i_rst_20mhz;

output reg eo_sck_t;
output reg eo_sck_o;
output reg eo_csn_t;
output reg eo_csn_o;
output reg eo_copi_t;
output reg eo_copi_o;
input wire ei_cipo;

input wire ei_int1;
input wire ei_int2;

output wire o_command_ready;
input wire i_cmd_init_linked_mode;
input wire i_cmd_start_linked_mode;
input wire i_cmd_init_measur_mode;
input wire i_cmd_start_measur_mode;
input wire i_cmd_soft_reset_acl2;

output reg [63:0] o_data_3axis_temp; /* Eight bytes of measurement data. */
output reg o_data_valid;
output wire [7:0] o_reg_status; /* Status register is one byte. */

input wire [1:0] i_btn_deb;
output wire [3:0] o_enum_active;
output wire [3:0] o_enum_inactive;

//Part 2: Declarations----------------------------------------------------------

/* Include the threshold presets to define parameter values for the threshold
   preset selectors. */
`include "thresh_presets_include.vh"

/* ACL2 SPI driver wiring to the Generic SPI driver. */
wire s_acl2_clk_spi_4x;
wire s_acl2_rst_spi_4x;
wire s_acl2_go_stand;
wire s_acl2_spi_idle;
wire [(parm_tx_len_bits - 1):0] s_acl2_tx_len;
wire [(parm_wait_cyc_bits - 1):0] s_acl2_wait_cyc;
wire [(parm_rx_len_bits - 1):0] s_acl2_rx_len;
wire [7:0] s_acl2_tx_data;
wire s_acl2_tx_enqueue;
wire s_acl2_tx_ready;
wire [7:0] s_acl2_rx_data;
wire s_acl2_rx_dequeue;
wire s_acl2_rx_valid;
wire s_acl2_rx_avail;

/* ACL2 SPI driver variables for streaming the 8 bytes of measurement values. */
wire [7:0] s_acl2_rd_data_stream;
wire s_acl2_rd_data_byte_valid;
wire s_acl2_rd_data_group_valid;
reg [(8*8-1):0] s_hex_3axis_temp_measurements_val;
reg [(8*8-1):0] s_hex_3axis_temp_measurements_aux;

/* ACL2 SPI outputs, FSM signals to register the SPI bus outputs for
   optimal timing closure and glitch minimization. */
wire sio_acl2_sck_fsm_o;
wire sio_acl2_sck_fsm_t;
wire sio_acl2_csn_fsm_o;
wire sio_acl2_csn_fsm_t;
wire sio_acl2_copi_fsm_o;
wire sio_acl2_copi_fsm_t;

/* ACL2 SPI input synchronizer signals, where the synchronizer is used to
   mitigate metastability. */
reg sio_acl2_cipo_meta_i;
reg sio_acl2_cipo_sync_i;

/* Debounced external interrupts. */
wire si_int1_debounced;
wire si_int2_debounced;

/* Experiment FSM state declarations */
`define c_stream_state_bits 2
localparam [(`c_stream_state_bits - 1):0] ST_WAIT_GROUP = 0;
localparam [(`c_stream_state_bits - 1):0] ST_WAIT_VALID = 1;
localparam [(`c_stream_state_bits - 1):0] ST_DONE_CYCLE = 2;

/* Xilinx attributes for Gray encoding of the FSM and safe state is
   Default State. */
(* fsm_encoding = "gray" *)
(* fsm_safe_state = "default_state" *)
reg [(`c_stream_state_bits - 1):0] s_stream_pr_state = ST_WAIT_GROUP;
reg [(`c_stream_state_bits - 1):0] s_stream_nx_state = ST_WAIT_GROUP;

localparam [3:0] c_j_max = 8;
reg [3:0] s_j_val;
reg [3:0] s_j_aux;

/* One-shot conversion of button levels */
wire s_btn0_one_shot;
wire s_btn1_one_shot;

/* Presets binary encoding for the seven registers on the ADXL362 chip */
wire [7*8-1:0] s_tx_ax_cfg0_lm;
wire [7:0] s_tx_ax_cfg0_discard;

//Part 3: Statements------------------------------------------------------------
/* One shot generation of Button 0 */
one_shot_fsm #() u_one_shot_fsm_btn0 (
	.x(i_btn_deb[0]),
	.clk(i_clk_20mhz),
	.rst(i_rst_20mhz),
	.y(s_btn0_one_shot));

/* One shot generation of Button 1 */
one_shot_fsm #() u_one_shot_fsm_btn1 (
	.x(i_btn_deb[1]),
	.clk(i_clk_20mhz),
	.rst(i_rst_20mhz),
	.y(s_btn1_one_shot));

/* Presets seletor for the Activity detection thresholds and timers */
thresh_presets_selector #(
	.parm_presets_config_thresholds(`c_thresh_presets_active_a_thresholds),
	.parm_presets_config_timers(`c_thresh_presets_active_a_timers)
	) u_thresh_presets_selector_active (
	.i_clk_20mhz(i_clk_20mhz),
	.i_rst_20mhz(i_rst_20mhz),
	.i_btn_chg_preset(s_btn0_one_shot),
	.o_value_enum(o_enum_active),
	.o_value_thresh({s_tx_ax_cfg0_lm[6*8-1-:8], s_tx_ax_cfg0_lm[7*8-1-:8]}),
	.o_value_timer({s_tx_ax_cfg0_discard, s_tx_ax_cfg0_lm[5*8-1-:8]})
	);

/* Presets seletor for the Activity detection thresholds and timers */
thresh_presets_selector #(
	.parm_presets_config_thresholds(`c_thresh_presets_inactive_a_thresholds),
	.parm_presets_config_timers(`c_thresh_presets_inactive_a_timers)
	) u_thresh_presets_selector_inactive (
	.i_clk_20mhz(i_clk_20mhz),
	.i_rst_20mhz(i_rst_20mhz),
	.i_btn_chg_preset(s_btn1_one_shot),
	.o_value_enum(o_enum_inactive),
	.o_value_thresh({s_tx_ax_cfg0_lm[3*8-1-:8], s_tx_ax_cfg0_lm[4*8-1-:8]}),
	.o_value_timer({s_tx_ax_cfg0_lm[1*8-1-:8], s_tx_ax_cfg0_lm[2*8-1-:8]})
	);

/* Register the SPI output an extra 4x-SPI-clock clock cycle. */
always @(posedge i_clk_20mhz)
begin: p_reg_spi_fsm_out
	eo_sck_o <= sio_acl2_sck_fsm_o;
	eo_sck_t <= sio_acl2_sck_fsm_t;

	eo_csn_o <= sio_acl2_csn_fsm_o;
	eo_csn_t <= sio_acl2_csn_fsm_t;

	eo_copi_o <= sio_acl2_copi_fsm_o;
	eo_copi_t <= sio_acl2_copi_fsm_t;
end

/* Double-register the SPI input at 4x-SPI-clock cycle to prevent metastability. */
always @(posedge i_clk_20mhz)
begin: p_sync_spi_in
	sio_acl2_cipo_sync_i <= sio_acl2_cipo_meta_i;
	sio_acl2_cipo_meta_i <= ei_cipo;
end

/* Multiple mode driver to operate the PMOD ACL2 via a stand-alone SPI driver. */
pmod_acl2_stand_spi_solo #(
	.parm_fast_simulation (parm_fast_simulation),
	.FCLK (FCLK),
	.parm_tx_len_bits  (parm_tx_len_bits),
	.parm_wait_cyc_bits (parm_wait_cyc_bits),
	.parm_rx_len_bits  (parm_rx_len_bits)
	) u_pmod_acl2_stand_spi_solo (
	.i_ext_spi_clk_x(i_clk_20mhz),
	.i_srst(i_rst_20mhz),
	.i_spi_ce_4x(1'b1), /* clock enable is held '1' as 20 MHz is 4x the SPI clock */
	.ei_int1(si_int1_debounced),
	.ei_int2(si_int2_debounced),

	.o_go_stand(s_acl2_go_stand),
	.i_spi_idle(s_acl2_spi_idle),
	.o_tx_len(s_acl2_tx_len),
	.o_wait_cyc(s_acl2_wait_cyc),
	.o_rx_len(s_acl2_rx_len),

	.o_tx_data(s_acl2_tx_data),
	.o_tx_enqueue(s_acl2_tx_enqueue),
	.i_tx_ready(s_acl2_tx_ready),

	.i_rx_data(s_acl2_rx_data),
	.o_rx_dequeue(s_acl2_rx_dequeue),
	.i_rx_valid(s_acl2_rx_valid),
	.i_rx_avail(s_acl2_rx_avail),

	.o_command_ready(o_command_ready),
	.i_cmd_init_linked_mode (i_cmd_init_linked_mode),
	.i_cmd_start_linked_mode(i_cmd_start_linked_mode),
	.i_cmd_init_measur_mode (i_cmd_init_measur_mode),
	.i_cmd_start_measur_mode(i_cmd_start_measur_mode),
	.i_cmd_soft_reset_acl2(i_cmd_soft_reset_acl2),

	.o_rd_data_stream(s_acl2_rd_data_stream),
	.o_rd_data_byte_valid(s_acl2_rd_data_byte_valid),
	.o_rd_data_group_valid(s_acl2_rd_data_group_valid),

	.o_reg_status(o_reg_status),

	.i_tx_ax_cfg0_lm(s_tx_ax_cfg0_lm));

/* Stand-alone SPI bus driver for a single bus-peripheral. */
pmod_generic_spi_solo #(
	.parm_ext_spi_clk_ratio (parm_ext_spi_clk_ratio),
	.parm_tx_len_bits  (parm_tx_len_bits),
	.parm_wait_cyc_bits (parm_wait_cyc_bits),
	.parm_rx_len_bits  (parm_rx_len_bits)
	) u_pmod_generic_spi_solo (
	.eo_sck_o(sio_acl2_sck_fsm_o),
	.eo_sck_t(sio_acl2_sck_fsm_t),
	.eo_csn_o(sio_acl2_csn_fsm_o),
	.eo_csn_t(sio_acl2_csn_fsm_t),
	.eo_copi_o(sio_acl2_copi_fsm_o),
	.eo_copi_t(sio_acl2_copi_fsm_t),
	.ei_cipo_i(sio_acl2_cipo_sync_i),

	.i_ext_spi_clk_x(i_clk_20mhz),
	.i_srst(i_rst_20mhz),
	.i_spi_ce_4x(1'b1), /* 20 MHz is 4x the SPI speed, so CE is held '1' */

	.i_go_stand(s_acl2_go_stand),
	.o_spi_idle(s_acl2_spi_idle),
	.i_tx_len(s_acl2_tx_len),
	.i_wait_cyc(s_acl2_wait_cyc),
	.i_rx_len(s_acl2_rx_len),

	.i_tx_data(s_acl2_tx_data),
	.i_tx_enqueue(s_acl2_tx_enqueue),
	.o_tx_ready(s_acl2_tx_ready),

	.o_rx_data(s_acl2_rx_data),
	.i_rx_dequeue(s_acl2_rx_dequeue),
	.o_rx_valid(s_acl2_rx_valid),
	.o_rx_avail(s_acl2_rx_avail));

/* Synchronize and debounce the INT1 incoming signal from PMOD ACL2. */
ext_interrupt_debouncer #() u_extint_deb_int1 (
	si_int1_debounced, i_clk_20mhz, i_rst_20mhz, ei_int1);

/* Synchronize and debounce the INT2 incoming signal from PMOD ACL2. */
ext_interrupt_debouncer #() u_extint_deb_int2 (
	si_int2_debounced, i_clk_20mhz, i_rst_20mhz, ei_int2);

/* FSM states for streaming data from the PMOD ACL2 to a buffer from which
   other logic reads the hexadecimal values of the X-Axis, Y-Axis,
   Z-Axis, Temperature. */
always @(posedge i_clk_20mhz)
begin: p_stream_fsm_state_aux
	if (i_rst_20mhz) begin
		s_stream_pr_state <= ST_WAIT_GROUP;

		s_j_aux <= 0;
		s_hex_3axis_temp_measurements_aux <= 0;
		o_data_3axis_temp <= 0;
	end else begin
		s_stream_pr_state <= s_stream_nx_state;

		s_j_aux <= s_j_val;
		s_hex_3axis_temp_measurements_aux <=
			s_hex_3axis_temp_measurements_val;

		if ((s_stream_pr_state == ST_DONE_CYCLE) &&
			(s_stream_nx_state == ST_WAIT_GROUP)) begin
			o_data_3axis_temp <= s_hex_3axis_temp_measurements_aux;
			o_data_valid <= 1'b1;
		end else
			o_data_valid <= 1'b0;
	end
end

/* FSM Combinatorial for capturing streamed measurements from the PMOD ACL2
   driver output in order that a high level module may use the captured byte
   data to display either engineer-readable values from the ADXL362, or
   physical milli-g acceleration values in human-readable form. */
/* Note that the \ref pmod_acl2_stand_spi_solo driver provides two pulses for
   reading the incoming measurement reading bytes from the PMOD ACL2. The
   GROUP VALID pulse lasts at an active value of one for the duration of 
   reading via SPI and outputting valid bytes. The BYTE VALID pulse lasts for
   exactly one SPI-4x-clock cycle during the valid value of a received byte
   that belongs to the group of bytes. In this way, the GROUP VALID restarts
   receipt of byte data; and the BYTE VALID indicates when to read a valid
   incoming byte. */
always @(s_stream_pr_state, s_acl2_rd_data_stream, s_acl2_rd_data_group_valid,
	s_acl2_rd_data_byte_valid, s_j_aux, s_hex_3axis_temp_measurements_aux)
begin: p_stream_fsm_comb
	case (s_stream_pr_state)
		ST_WAIT_VALID: begin
			if (s_j_aux == c_j_max) begin
				/* hold the byte count */
				s_j_val = s_j_aux;

				/* hold the 8 byte measurement value from shifting */
				s_hex_3axis_temp_measurements_val =
					s_hex_3axis_temp_measurements_aux;

				/* data is captured as valid on the exit of the next state,
				   \ref ST_DONE_CYCLE so transition */
				s_stream_nx_state = ST_DONE_CYCLE;
			end else if (s_acl2_rd_data_byte_valid) begin
				/* count up the byte value */
				s_j_val = s_j_aux + 1;

				/* shift-in the new stream byte */
				s_hex_3axis_temp_measurements_val =
					{s_hex_3axis_temp_measurements_aux[(7*8-1)-:(7*8)],
					 s_acl2_rd_data_stream};

				/* stay in this state for more captures */
				s_stream_nx_state = ST_WAIT_VALID;
			end else begin
				/* hold the byte count */
				s_j_val = s_j_aux;

				/* hold the 8 byte measurement value from shifting */
				s_hex_3axis_temp_measurements_val =
					s_hex_3axis_temp_measurements_aux;

				/* stay in this state */
				s_stream_nx_state = ST_WAIT_VALID;
			end
		end
		ST_DONE_CYCLE: begin
			/* hold the byte count */
			s_j_val = s_j_aux;

			/* hold the 8 byte measurement value from shifting */
			s_hex_3axis_temp_measurements_val = s_hex_3axis_temp_measurements_aux;

			/* wait for GROUP VALID to deassert, and on this state
			   transition, the synchronous state process will capture
			   the 8 bytes of measurement value. */
			if (! s_acl2_rd_data_group_valid) s_stream_nx_state = ST_WAIT_GROUP;
			else s_stream_nx_state = ST_DONE_CYCLE;
		end
		default: begin // ST_WAIT_GROUP
			/* preset the byte count to zero */
			s_j_val = 0;

			/* preset the 8 byte measurement value as zeros */
			s_hex_3axis_temp_measurements_val = 0;

			/* wait for GROUP VALID to then wait for BYTE VALID */
			if (s_acl2_rd_data_group_valid) s_stream_nx_state = ST_WAIT_VALID;
			else s_stream_nx_state = ST_WAIT_GROUP;
		end
	endcase
end

endmodule
//------------------------------------------------------------------------------
