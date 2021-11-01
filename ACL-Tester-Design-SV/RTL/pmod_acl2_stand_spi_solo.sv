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
-- \file pmod_acl2_stand_spi_solo.sv
--
-- \brief A custom driver to operate the PMOD ACL2 accelerometer with ADXL362,
-- that relies upon \ref pmod_generic_spi_solo to implement the Standard SPI
-- interface.
------------------------------------------------------------------------------*/
//------------------------------------------------------------------------------
`begin_keywords "1800-2009"
//Recursive Moore Machine
//Part 1: Module header:--------------------------------------------------------
module pmod_acl2_stand_spi_solo
	import pmod_stand_spi_solo_pkg::*;
	#(parameter
		/* Disable or enable fast FSM delays for simulation instead of impelementation. */
		integer parm_fast_simulation = 0,
		/* Actual frequency in Hz of \ref i_ext_spi_clk_4x */
		integer FCLK = 20000000
		)
	(
		/* system clock and synchronous reset */
		input logic i_ext_spi_clk_x,
		input logic i_srst,
		input logic i_spi_ce_4x,
		/* interrupt lines of the PMOD ACL2 */
		input logic ei_int1,
		input logic ei_int2,
		/* Interface pmod_generic_spi_solo_intf */
		pmod_generic_spi_solo_intf.spi_sysdrv sdrv,
		/* FPGA system interface to ACL2 operation */
		output logic o_command_ready,
		input logic i_cmd_init_linked_mode,
		input logic i_cmd_start_linked_mode,
		input logic i_cmd_init_measur_mode,
		input logic i_cmd_start_measur_mode,
		input logic i_cmd_soft_reset_acl2,
		/* measurement data streaming output of the accelerometer */
		output t_pmod_acl2_data_byte o_rd_data_stream,
		output logic o_rd_data_byte_valid,
		output logic o_rd_data_group_valid,
		/* data status of accelerometer */
		output t_pmod_acl2_reg_1 o_reg_status,
		/* run-time dynamic configuration */
		input t_pmod_acl2_reg_7 i_tx_ax_cfg0_lm);

// Part 2: Declarations---------------------------------------------------------
timeunit 1ns;
timeprecision 1ps;

/* Timer signals and constants */
localparam integer c_acl2_drv_time_value_bits = 24;
typedef logic [(c_acl2_drv_time_value_bits - 1):0] t_acl2_drv_time_value;

/* Boot time should be in hundreds of milliseconds as the ADXL362 lists on
   page 5 of datasheet Rev. F that the Power-Up to Standby time is
   5 milliseconds typical, and does not list a maximum time. */
/* This constant can be overriden with a fast boot delay by passing a non-zero
   to the parameter \ref parm_fast_simulation */
localparam t_acl2_drv_time_value c_t_adxl362_boot =
	parm_fast_simulation ? (FCLK * 1 / 10000) : (FCLK * 100 / 1000);
localparam t_acl2_drv_time_value c_tmax = c_t_adxl362_boot - 1;

t_acl2_drv_time_value s_t;


/* ADXL362 command bytes. */
localparam [7:0] c_adxl362_cmd_write = 8'h0A;
localparam [7:0] c_adxl362_cmd_read = 8'h0B;
localparam [7:0] c_adxl362_cmd_fifo = 8'h0D;

/* ADXL362 configurable register areas according to Applications section of the
   datasheeet: the starting address of these sections. */
localparam [7:0] c_adxl362_addr_cfg0 = 8'h20;
localparam [7:0] c_adxl362_addr_cfg1 = 8'h27;
localparam [7:0] c_adxl362_addr_cfg2 = 8'h28;
localparam [7:0] c_adxl362_addr_cfg3 = 8'h2A;
localparam [7:0] c_adxl362_addr_cfg4 = 8'h2C;
localparam [7:0] c_adxl362_addr_cfg5 = 8'h2D;
localparam [7:0] c_adxl362_addr_8reg = 8'h0E;
localparam [7:0] c_adxl362_addr_stat = 8'h0B;
localparam [7:0] c_adxl362_addr_sr = 8'h1F;
localparam [7:0] c_adxl362_data_sr = 8'h52;

/* Count of bytes to TX and count of bytes to RX, for each operation of the
   state machine. */
localparam t_pmod_acl2_tx_len c_tx_ax_cfg0_length = 2 + 7;
localparam t_pmod_acl2_tx_len c_tx_ax_cfg1_length = 2 + 1;
localparam t_pmod_acl2_tx_len c_tx_ax_cfg2_length = 2 + 2;
localparam t_pmod_acl2_tx_len c_tx_ax_cfg3_length = 2 + 2;
localparam t_pmod_acl2_tx_len c_tx_ax_cfg4_length = 2 + 1;
localparam t_pmod_acl2_tx_len c_tx_ax_cfg5_length = 2 + 1;
localparam t_pmod_acl2_tx_len c_tx_ax_sr_length = 2 + 1;
localparam t_pmod_acl2_tx_len c_tx_ax_readmm_length = 2;
localparam t_pmod_acl2_rx_len c_rx_ax_readmm_length = 8;
localparam t_pmod_acl2_tx_len c_tx_ax_clearmm_length = 2;
localparam t_pmod_acl2_rx_len c_rx_ax_clearmm_length = 1;
localparam t_pmod_acl2_tx_len c_tx_ax_readlm_length = 2;
localparam t_pmod_acl2_rx_len c_rx_ax_readlm_length = 8;
localparam t_pmod_acl2_tx_len c_tx_ax_clearlm_length = 2;
localparam t_pmod_acl2_rx_len c_rx_ax_clearlm_length = 1;

/* 0x20 : 0x26 */
localparam t_pmod_acl2_reg_7 c_tx_ax_cfg0_lm =
	/* THRESH_ACT_L, THRESH_ACT_H, TIME_ACT, THRESH_INACT_L, THRESH_INACT_H,
	   TIME_INACT_L, TIME_INACT_H */
	{8'h20, 8'h00, 8'h64, 8'h1A, 8'h00,
	 8'h64, 8'h00};

/* 0x27 */
localparam t_pmod_acl2_reg_1 c_tx_ax_cfg1_lm =
	/* ACT_INACT_CTL */
	8'b00011111;

/* 0x28 : 0x29 */
localparam t_pmod_acl2_reg_2 c_tx_ax_cfg2_lm =
	/* FIFO_CONTROL, FIFO_SAMPLES */
	{8'b00000000, 8'b00000000};

/* 0x2A : 0x2B */
localparam t_pmod_acl2_reg_2 c_tx_ax_cfg3_lm =
	/* INTMAP1, INTMAP2 */
	{8'h20, 8'h10};

/* 0x2C */
localparam t_pmod_acl2_reg_1 c_tx_ax_cfg4_lm =
	/* FILTER_CTL */
	{8'b00010011};

/* 0x2D */
localparam t_pmod_acl2_reg_1 c_tx_ax_cfg5_lm =
	/* POWER_CTL */
	{8'b00100010};

/* 0x20 : 0x26 */
localparam t_pmod_acl2_reg_7 c_tx_ax_cfg0_mm =
	/* THRESH_ACT_L, THRESH_ACT_H, TIME_ACT, THRESH_INACT_L, THRESH_INACT_H,
	   TIME_INACT_L, TIME_INACT_H */
	{8'h14, 8'h00, 8'h64, 8'h10, 8'h00,
	 8'h64, 8'h00};

/* 0x27 */
localparam t_pmod_acl2_reg_1 c_tx_ax_cfg1_mm =
	/* ACT_INACT_CTL */
	8'b00000101;

/* 0x28 : 0x29 */
localparam t_pmod_acl2_reg_2 c_tx_ax_cfg2_mm =
	/* FIFO_CONTROL, FIFO_SAMPLES */
	{8'b00000000, 8'b00000000};

/* 0x2A : 0x2B */
localparam t_pmod_acl2_reg_2 c_tx_ax_cfg3_mm =
	/* INTMAP1, INTMAP2 */
	{8'h01, 8'h00};

/* 0x2C */
localparam t_pmod_acl2_reg_1 c_tx_ax_cfg4_mm =
	/* FILTER_CTL */
	{8'b00010011};

/* 0x2D */
localparam t_pmod_acl2_reg_1 c_tx_ax_cfg5_mm =
	/* POWER_CTL */
	{8'b00100010};


/* Xilinx attributes for Gray encoding of the FSM and safe state is
   Default State. */
(* fsm_encoding = "auto" *)
(* fsm_safe_state = "default_state" *)
/* Driver FSM state declarations */
`define c_drv_state_bits 6
typedef enum logic [(`c_drv_state_bits - 1):0] {
	ST_DRV_BOOT0, ST_DRV_IDLE0, ST_DRV_INIT_LM, ST_DRV_INIT_MM,
	ST_DRV_WR_AX_CFG0_CMD, ST_DRV_WR_AX_CFG0_ADDR, ST_DRV_WR_AX_CFG0_DATA, ST_DRV_WAIT_AX_CFG0,
	ST_DRV_WR_AX_CFG1_CMD, ST_DRV_WR_AX_CFG1_ADDR, ST_DRV_WR_AX_CFG1_DATA, ST_DRV_WAIT_AX_CFG1,
	ST_DRV_WR_AX_CFG2_CMD, ST_DRV_WR_AX_CFG2_ADDR, ST_DRV_WR_AX_CFG2_DATA, ST_DRV_WAIT_AX_CFG2,
	ST_DRV_WR_AX_CFG3_CMD, ST_DRV_WR_AX_CFG3_ADDR, ST_DRV_WR_AX_CFG3_DATA, ST_DRV_WAIT_AX_CFG3,
	ST_DRV_WR_AX_CFG4_CMD, ST_DRV_WR_AX_CFG4_ADDR, ST_DRV_WR_AX_CFG4_DATA, ST_DRV_WAIT_AX_CFG4,
	ST_DRV_WR_AX_CFG5_CMD, ST_DRV_WR_AX_CFG5_ADDR, ST_DRV_WR_AX_CFG5_DATA, ST_DRV_WAIT_AX_CFG5,
	ST_DRV_IDLE1,
	ST_DRV_WAIT_DR_INT1, ST_DRV_READ_MEASU_CMD, ST_DRV_READ_MEASU_ADDR, ST_DRV_READ_MEASU_DATA,
	ST_DRV_READ_WAIT0, ST_DRV_CLEAR_MEASU_CMD, ST_DRV_CLEAR_MEASU_ADDR,
	ST_DRV_CLEAR_MEASU_DATA, ST_DRV_READ_WAIT1, ST_DRV_READ_WAIT2,
	ST_DRV_WAIT_AT_INT1, ST_DRV_READ_INACT0_CMD, ST_DRV_READ_INACT0_ADDR, ST_DRV_READ_INACT0_DATA,
	ST_DRV_READ_WAIT3, ST_DRV_CLEAR_AWAKE0_CMD, ST_DRV_CLEAR_AWAKE0_ADDR,
	ST_DRV_CLEAR_AWAKE0_DATA, ST_DRV_READ_WAIT4, ST_DRV_READ_WAIT5,
	ST_DRV_WAIT_AT_INT2, ST_DRV_READ_ACT0_CMD, ST_DRV_READ_ACT0_ADDR, ST_DRV_READ_ACT0_DATA,
	ST_DRV_READ_WAIT6, ST_DRV_CLEAR_AWAKE1_CMD, ST_DRV_CLEAR_AWAKE1_ADDR,
	ST_DRV_CLEAR_AWAKE1_DATA, ST_DRV_READ_WAIT7, ST_DRV_READ_WAIT8,
	ST_DRV_SOFTRESET_CMD, ST_DRV_SOFTRESET_ADDR, ST_DRV_SOFTRESET_DATA, ST_DRV_SOFTRESET_WAIT9
} t_drv_state;
t_drv_state s_drv_pr_state;
t_drv_state s_drv_nx_state;

/* Auxiliary state machine registers for recursive state machine operation. */
t_pmod_acl2_reg_7 s_tx_ax_cfg0_val;
t_pmod_acl2_reg_7 s_tx_ax_cfg0_aux;
t_pmod_acl2_reg_1 s_tx_ax_cfg1_val;
t_pmod_acl2_reg_1 s_tx_ax_cfg1_aux;
t_pmod_acl2_reg_2 s_tx_ax_cfg2_val;
t_pmod_acl2_reg_2 s_tx_ax_cfg2_aux;
t_pmod_acl2_reg_2 s_tx_ax_cfg3_val;
t_pmod_acl2_reg_2 s_tx_ax_cfg3_aux;
t_pmod_acl2_reg_1 s_tx_ax_cfg4_val;
t_pmod_acl2_reg_1 s_tx_ax_cfg4_aux;
t_pmod_acl2_reg_1 s_tx_ax_cfg5_val;
t_pmod_acl2_reg_1 s_tx_ax_cfg5_aux;
logic [7:0] s_byte_index_val;
logic [7:0] s_byte_index_aux;
t_pmod_acl2_reg_1 s_reg_status_val;
t_pmod_acl2_reg_1 s_reg_status_aux;

//Part 3: Statements------------------------------------------------------------
assign o_reg_status = s_reg_status_aux;

/* Timer 1 (Strategy #1), for timing the boot wait for PMOD ACL2 communication */
always_ff @(posedge i_ext_spi_clk_x)
begin: p_timer_1
	if (i_srst)	s_t <= 0;
	else
		if (i_spi_ce_4x)
			if (s_drv_pr_state != s_drv_nx_state) begin : if_chg_state
				s_t <= 0;
			end : if_chg_state

			else if (s_t < c_tmax) begin : if_not_timer_max
				s_t <= s_t + 1;
			end : if_not_timer_max

end : p_timer_1

/* FSM state register plus auxiliary registers, for propagating the next state
   as well as the next recursive auxiliary register value for use within
   one or more state combinatorial logic decisions. */
always_ff @(posedge i_ext_spi_clk_x)
begin: p_fsm_state_aux
	if (i_srst) begin
		s_drv_pr_state <= ST_DRV_BOOT0;

		s_tx_ax_cfg0_aux <= '0;
		s_tx_ax_cfg1_aux <= '0;
		s_tx_ax_cfg2_aux <= '0;
		s_tx_ax_cfg3_aux <= '0;
		s_tx_ax_cfg4_aux <= '0;
		s_tx_ax_cfg5_aux <= '0;
		s_byte_index_aux <= 0;
		s_reg_status_aux <= '0;
	end else 
		if (i_spi_ce_4x) begin : if_fsm_state_and_storage
			s_drv_pr_state <= s_drv_nx_state;

			s_tx_ax_cfg0_aux <= s_tx_ax_cfg0_val;
			s_tx_ax_cfg1_aux <= s_tx_ax_cfg1_val;
			s_tx_ax_cfg2_aux <= s_tx_ax_cfg2_val;
			s_tx_ax_cfg3_aux <= s_tx_ax_cfg3_val;
			s_tx_ax_cfg4_aux <= s_tx_ax_cfg4_val;
			s_tx_ax_cfg5_aux <= s_tx_ax_cfg5_val;
			s_byte_index_aux <= s_byte_index_val;
			s_reg_status_aux <= s_reg_status_val;
		end : if_fsm_state_and_storage
end : p_fsm_state_aux

/* FSM combinatorial logic providing multiple outputs, assigned in every state,
   as well as changes in auxiliary values, and calculation of the next FSM
   state. Refer to the FSM state machine drawings in document:
   \ref exercise-14-10-drawing.pdf . */
always_comb
begin: p_fsm_comb
	/* default values were not set here with blocking assignment,
	   because it is anticipated to do so would cause potential glitches
	   in the combinatorial logic. blocking assignment is used instead
	   of non-blocking assignment only because that is a prerequisite
	   for Xilinx Vivado to synthesize a fully combinatorial logic
	   block. outputs and auxiliary registers must be assigned in
	   every case of the FSM state, including a default: clause for
	   unlisted binary state values to default to the initial state. */
	case (s_drv_pr_state)
		ST_DRV_INIT_LM: begin
			 /* Load auxiliary registers with Linked Mode configuration. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = i_tx_ax_cfg0_lm;
			s_tx_ax_cfg1_val = c_tx_ax_cfg1_lm;
			s_tx_ax_cfg2_val = c_tx_ax_cfg2_lm;
			s_tx_ax_cfg3_val = c_tx_ax_cfg3_lm;
			s_tx_ax_cfg4_val = c_tx_ax_cfg4_lm;
			s_tx_ax_cfg5_val = c_tx_ax_cfg5_lm;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			s_drv_nx_state = ST_DRV_WR_AX_CFG0_CMD;
		end

		ST_DRV_INIT_MM: begin
			 /* Load auxiliary registers with Measurement Mode configuration. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = c_tx_ax_cfg0_mm;
			s_tx_ax_cfg1_val = c_tx_ax_cfg1_mm;
			s_tx_ax_cfg2_val = c_tx_ax_cfg2_mm;
			s_tx_ax_cfg3_val = c_tx_ax_cfg3_mm;
			s_tx_ax_cfg4_val = c_tx_ax_cfg4_mm;
			s_tx_ax_cfg5_val = c_tx_ax_cfg5_mm;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;
			
			s_drv_nx_state = ST_DRV_WR_AX_CFG0_CMD;
		end

		ST_DRV_WR_AX_CFG0_CMD: begin
			/* Load first byte, command WRITE, to TX FIFO. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_write;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg0_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready) begin
				s_drv_nx_state = ST_DRV_WR_AX_CFG0_ADDR;
			end else begin
				s_drv_nx_state = ST_DRV_WR_AX_CFG0_CMD;
			end
		end

		ST_DRV_WR_AX_CFG0_ADDR: begin
			/* Load second byte, starting address for Configuration 0 byte sequence, to TX FIFO */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_cfg0;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg0_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = (c_tx_ax_cfg0_length - 2);
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready) begin
				s_drv_nx_state = ST_DRV_WR_AX_CFG0_DATA;
			end else begin
				s_drv_nx_state = ST_DRV_WR_AX_CFG0_ADDR;
			end
		end

		ST_DRV_WR_AX_CFG0_DATA: begin
			/* Load \ref c_tx_ax_cfg0_length - 2 count of register WRITE data bytes,
			   and then trigger the Standard SPI operation. */
			o_command_ready = 1'b0;
			sdrv.tx_len = c_tx_ax_cfg0_length;
			sdrv.tx_data = s_tx_ax_cfg0_aux[((s_byte_index_aux * 8) - 1) -: 8];
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = (s_byte_index_aux > 1) ? 1'b0 : (sdrv.tx_ready ? 1'b1 : 1'b0);
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = (sdrv.tx_ready) ? (s_byte_index_aux - 1) : (s_byte_index_aux);
			s_reg_status_val = s_reg_status_aux;			

			if ((sdrv.tx_ready == 1'b1) && (s_byte_index_aux <= 1))
				s_drv_nx_state = ST_DRV_WAIT_AX_CFG0;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG0_DATA;
		end

		ST_DRV_WAIT_AX_CFG0: begin
			/* Wait for the SPI operation to complete and return to IDLE */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_cfg0_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_WR_AX_CFG1_CMD;
			else s_drv_nx_state = ST_DRV_WAIT_AX_CFG0;
		end

		ST_DRV_WR_AX_CFG1_CMD: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_write;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg1_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_WR_AX_CFG1_ADDR;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG1_CMD;
		end

		ST_DRV_WR_AX_CFG1_ADDR: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_cfg1;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg1_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = (c_tx_ax_cfg1_length - 2);
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_WR_AX_CFG1_DATA;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG1_ADDR;
		end

		ST_DRV_WR_AX_CFG1_DATA: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = s_tx_ax_cfg1_aux[((s_byte_index_aux * 8) - 1) -: 8];
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg1_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = (s_byte_index_aux > 1) ? 1'b0 : (sdrv.tx_ready ? 1'b1 : 1'b0);
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = sdrv.tx_ready ? (s_byte_index_aux - 1) : s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if ((sdrv.tx_ready == 1'b1)  && (s_byte_index_aux <= 1))
				s_drv_nx_state = ST_DRV_WAIT_AX_CFG1;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG1_DATA;
		end

		ST_DRV_WAIT_AX_CFG1: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_cfg1_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_WR_AX_CFG2_CMD;
			else s_drv_nx_state = ST_DRV_WAIT_AX_CFG1;
		end

		ST_DRV_WR_AX_CFG2_CMD: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_write;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg2_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_WR_AX_CFG2_ADDR;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG2_CMD;
		end

		ST_DRV_WR_AX_CFG2_ADDR: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_cfg2;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg2_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = (c_tx_ax_cfg2_length - 2);
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_WR_AX_CFG2_DATA;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG2_ADDR;
		end

		ST_DRV_WR_AX_CFG2_DATA: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_len = c_tx_ax_cfg2_length;
			sdrv.tx_data = s_tx_ax_cfg2_aux[((s_byte_index_aux * 8) - 1) -: 8];
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = (s_byte_index_aux > 1) ? 1'b0 : (sdrv.tx_ready ? 1'b1 : 1'b0);
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = sdrv.tx_ready ? (s_byte_index_aux - 1) : s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				if (s_byte_index_aux > 1)
					s_drv_nx_state = ST_DRV_WR_AX_CFG2_DATA;
				else
					s_drv_nx_state = ST_DRV_WAIT_AX_CFG2;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG2_DATA;
		end

		ST_DRV_WAIT_AX_CFG2: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_cfg2_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_WR_AX_CFG3_CMD;
			else s_drv_nx_state = ST_DRV_WAIT_AX_CFG2;
		end

		ST_DRV_WR_AX_CFG3_CMD: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_write;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg3_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_WR_AX_CFG3_ADDR;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG3_CMD;
		end

		ST_DRV_WR_AX_CFG3_ADDR: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_cfg3;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg3_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = (c_tx_ax_cfg3_length - 2);
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_WR_AX_CFG3_DATA;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG3_ADDR;
		end

		ST_DRV_WR_AX_CFG3_DATA: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_len = c_tx_ax_cfg3_length;
			sdrv.tx_data = s_tx_ax_cfg3_aux[((s_byte_index_aux * 8) - 1) -: 8];
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = (s_byte_index_aux > 1) ? 1'b0 : (sdrv.tx_ready ? 1'b1 : 1'b0);
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = sdrv.tx_ready ? (s_byte_index_aux - 1) : s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				if (s_byte_index_aux > 1)
					s_drv_nx_state = ST_DRV_WR_AX_CFG3_DATA;
				else
					s_drv_nx_state = ST_DRV_WAIT_AX_CFG3;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG3_DATA;
		end

		ST_DRV_WAIT_AX_CFG3: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_cfg3_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_WR_AX_CFG4_CMD;
			else s_drv_nx_state = ST_DRV_WAIT_AX_CFG3;
		end

		ST_DRV_WR_AX_CFG4_CMD: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_write;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg4_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_WR_AX_CFG4_ADDR;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG4_CMD;
		end

		ST_DRV_WR_AX_CFG4_ADDR: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_cfg4;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg4_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = (c_tx_ax_cfg4_length - 2);
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_WR_AX_CFG4_DATA;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG4_ADDR;
		end

		ST_DRV_WR_AX_CFG4_DATA: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = s_tx_ax_cfg4_aux[((s_byte_index_aux * 8) - 1) -: 8];
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg4_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = (s_byte_index_aux > 1) ? 1'b0 : (sdrv.tx_ready ? 1'b1 : 1'b0);
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = sdrv.tx_ready ? (s_byte_index_aux - 1) : s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				if (s_byte_index_aux > 1)
					s_drv_nx_state = ST_DRV_WR_AX_CFG4_DATA;
				else
					s_drv_nx_state = ST_DRV_WAIT_AX_CFG4;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG4_DATA;
		end

		ST_DRV_WAIT_AX_CFG4: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_cfg4_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_WR_AX_CFG5_CMD;
			else s_drv_nx_state = ST_DRV_WAIT_AX_CFG4;
		end

		ST_DRV_WR_AX_CFG5_CMD: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_write;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg5_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_WR_AX_CFG5_ADDR;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG5_CMD;
		end

		ST_DRV_WR_AX_CFG5_ADDR: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_cfg5;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_cfg5_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = (c_tx_ax_cfg5_length - 2);
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_WR_AX_CFG5_DATA;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG5_ADDR;
		end

		ST_DRV_WR_AX_CFG5_DATA: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_len = c_tx_ax_cfg5_length;
			sdrv.tx_data = s_tx_ax_cfg5_aux[((s_byte_index_aux * 8) - 1) -: 8];
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = (s_byte_index_aux > 1) ? 1'b0 : (sdrv.tx_ready ? 1'b1 : 1'b0);
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = sdrv.tx_ready ? (s_byte_index_aux - 1) : s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				if (s_byte_index_aux > 1)
					s_drv_nx_state = ST_DRV_WR_AX_CFG5_DATA;
				else
					s_drv_nx_state = ST_DRV_WAIT_AX_CFG5;
			else
				s_drv_nx_state = ST_DRV_WR_AX_CFG5_DATA;
		end

		ST_DRV_WAIT_AX_CFG5: begin
			/* Refer to the comments in the Configuration 0 sequence. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_cfg5_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_IDLE1;
			else s_drv_nx_state = ST_DRV_WAIT_AX_CFG5;
		end

		ST_DRV_WAIT_DR_INT1: begin
			/* If the SOFT RESET command is held, then transition to SOFT RESET operation.
			   If the Interrupt 1 is indicated (Data Ready status bit), then transition
			   to reading the full measurement of X, Y, Z, Temp.
			   Otherwise, wait for one of these two to occur. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (i_cmd_soft_reset_acl2) s_drv_nx_state = ST_DRV_SOFTRESET_CMD;
			else if (ei_int1) s_drv_nx_state = ST_DRV_READ_MEASU_CMD;
			else s_drv_nx_state = ST_DRV_WAIT_DR_INT1;
		end

		ST_DRV_READ_MEASU_CMD: begin
			/* Load first byte, command READ, to TX FIFO. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_read;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_readmm_length;
			sdrv.rx_len = c_rx_ax_readmm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b1;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_READ_MEASU_ADDR;
			else
				s_drv_nx_state = ST_DRV_READ_MEASU_CMD;
		end

		ST_DRV_READ_MEASU_ADDR: begin
			/* Load second byte, starting address for Measurements 8-byte sequence, to TX FIFO.
			   Then trigger the SPI bus operation. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_8reg;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_readmm_length;
			sdrv.rx_len = c_rx_ax_readmm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = sdrv.tx_ready;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b1;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = c_rx_ax_readmm_length;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_READ_MEASU_DATA;
			else
				s_drv_nx_state = ST_DRV_READ_MEASU_ADDR;
		end

		ST_DRV_READ_MEASU_DATA: begin
			/* Receive the eight bytes of measurment data from the SPI bus operation,
			   and output the bytes one-at-a-time in a streaming pattern. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_readmm_length;
			sdrv.rx_len = c_rx_ax_readmm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = sdrv.rx_avail;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = sdrv.rx_data;
			o_rd_data_byte_valid = sdrv.rx_valid;
			o_rd_data_group_valid = 1'b1;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = sdrv.rx_valid ? (s_byte_index_aux - 1) : s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;			

			if ((sdrv.rx_valid == 1'b1) && (s_byte_index_aux <= 1))
				s_drv_nx_state = ST_DRV_READ_WAIT0;
			else
				s_drv_nx_state = ST_DRV_READ_MEASU_DATA;
		end

		ST_DRV_READ_WAIT0: begin
			/* End the data stream GROUP signal, and wait for the SPI operation
			   to return to IDLE. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_readmm_length;
			sdrv.rx_len = c_rx_ax_readmm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b1;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_CLEAR_MEASU_CMD;
			else s_drv_nx_state = ST_DRV_READ_WAIT0;
		end

		ST_DRV_CLEAR_MEASU_CMD: begin
			/* Start a clearing of the status register currently indicating
			   DATA READY bit.
			   Load the READ command first. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_read;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_clearmm_length;
			sdrv.rx_len = c_rx_ax_clearmm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_CLEAR_MEASU_ADDR;
			else
				s_drv_nx_state = ST_DRV_CLEAR_MEASU_CMD;
		end

		ST_DRV_CLEAR_MEASU_ADDR: begin
			/* Next, load the STATUS REGISTER address and start the SPI
			   bus operation. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_stat;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_clearmm_length;
			sdrv.rx_len = c_rx_ax_clearmm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = sdrv.tx_ready;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = c_rx_ax_clearmm_length;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_CLEAR_MEASU_DATA;
			else
				s_drv_nx_state = ST_DRV_CLEAR_MEASU_ADDR;
		end

		ST_DRV_CLEAR_MEASU_DATA: begin
			/* Receive a new value for the STATUS REGISTER byte. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_clearmm_length;
			sdrv.rx_len = c_rx_ax_clearmm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = sdrv.rx_avail;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'b00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = sdrv.rx_valid ? (s_byte_index_aux - 1) : s_byte_index_aux;
			s_reg_status_val = sdrv.rx_valid ? sdrv.rx_data : s_reg_status_aux;

			if (sdrv.rx_valid)
				s_drv_nx_state = ST_DRV_READ_WAIT1;
			else
				s_drv_nx_state = ST_DRV_CLEAR_MEASU_DATA;
		end

		ST_DRV_READ_WAIT1: begin
			/* After reading the STATUS REGISTER, which clears the interrupts,
			   wait for the SPI operation to return to IDLE. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_READ_WAIT2;
			else s_drv_nx_state = ST_DRV_READ_WAIT1;
		end

		ST_DRV_READ_WAIT2: begin
			/* Reading the STATUS REGISTER should have cleared INT1 interrupt
			   pin. If it did, transition to state to wait on interrupt.
			   If it did not, try reading the STATUS REGISTER again. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (! ei_int1) s_drv_nx_state = ST_DRV_WAIT_DR_INT1;
			else s_drv_nx_state = ST_DRV_CLEAR_MEASU_CMD;
		end

		ST_DRV_WAIT_AT_INT1: begin
			/* If the SOFT RESET command is held, then transition to SOFT RESET operation.
			   If the Interrupt 1 is indicated (Inactivity status bit), then transition
			   to reading the full measurement of X, Y, Z, Temp.
			   If the Interrupt 2 is indicated (Activity status bit), then transition
			   to reading the full measurement of X, Y, Z, Temp.
			   Otherwise, wait for one of these three to occur. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (i_cmd_soft_reset_acl2) s_drv_nx_state = ST_DRV_SOFTRESET_CMD;
			else if (ei_int1) s_drv_nx_state = ST_DRV_READ_INACT0_CMD;
			else if (ei_int2) s_drv_nx_state = ST_DRV_READ_ACT0_CMD;
			else s_drv_nx_state = ST_DRV_WAIT_AT_INT1;
		end

		ST_DRV_READ_INACT0_CMD: begin
			/* Load first byte, command READ, to TX FIFO. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_read;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_readlm_length;
			sdrv.rx_len = c_rx_ax_readlm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b1;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_READ_INACT0_ADDR;
			else
				s_drv_nx_state = ST_DRV_READ_INACT0_CMD;
		end

		ST_DRV_READ_INACT0_ADDR: begin
			/* Load second byte, starting address for Measurements 8-byte sequence, to TX FIFO.
			   Then trigger the SPI bus operation. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_8reg;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_readlm_length;
			sdrv.rx_len = c_rx_ax_readlm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = sdrv.tx_ready;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b1;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = c_rx_ax_readlm_length;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_READ_INACT0_DATA;
			else
				s_drv_nx_state = ST_DRV_READ_INACT0_ADDR;
		end

		ST_DRV_READ_INACT0_DATA: begin
			/* Load second byte, starting address for Measurements 8-byte sequence, to TX FIFO.
			   Then trigger the SPI bus operation. */
			o_command_ready = 1'b0;
			sdrv.tx_len = c_tx_ax_readlm_length;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.rx_len = c_rx_ax_readlm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = sdrv.rx_avail;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = sdrv.rx_data;
			o_rd_data_byte_valid = sdrv.rx_valid;
			o_rd_data_group_valid = 1'b1;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = sdrv.rx_valid ? (s_byte_index_aux - 1) : s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;			

			if ((sdrv.rx_valid == 1'b1) && (s_byte_index_aux <= 1))
				s_drv_nx_state = ST_DRV_READ_WAIT3;
			else
				s_drv_nx_state = ST_DRV_READ_INACT0_DATA;
		end

		ST_DRV_READ_WAIT3: begin
			/* End the data stream GROUP signal, and wait for the SPI operation
			   to return to IDLE. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_readlm_length;
			sdrv.rx_len = c_rx_ax_readlm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b1;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_CLEAR_AWAKE0_CMD;
			else s_drv_nx_state = ST_DRV_READ_WAIT3;
		end

		ST_DRV_CLEAR_AWAKE0_CMD: begin
			/* Start a clearing of the status register currently indicating
			   INACTIVITY bit.
			   Load the READ command first. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_read;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_clearlm_length;
			sdrv.rx_len = c_rx_ax_clearlm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_CLEAR_AWAKE0_ADDR;
			else
				s_drv_nx_state = ST_DRV_CLEAR_AWAKE0_CMD;
		end

		ST_DRV_CLEAR_AWAKE0_ADDR: begin
			/* Next, load the STATUS REGISTER address and start the SPI
			   bus operation. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_stat;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_clearlm_length;
			sdrv.rx_len = c_rx_ax_clearlm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = sdrv.tx_ready;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = c_rx_ax_clearlm_length;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_CLEAR_AWAKE0_DATA;
			else
				s_drv_nx_state = ST_DRV_CLEAR_AWAKE0_ADDR;
		end

		ST_DRV_CLEAR_AWAKE0_DATA: begin
			/* Receive a new value for the STATUS REGISTER byte. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_clearmm_length;
			sdrv.rx_len = c_rx_ax_clearmm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = sdrv.rx_avail;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'b00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = sdrv.rx_valid ? (s_byte_index_aux - 1) : s_byte_index_aux;
			s_reg_status_val = sdrv.rx_valid ? sdrv.rx_data : s_reg_status_aux;

			if (sdrv.rx_valid) 
				s_drv_nx_state = ST_DRV_READ_WAIT4;
			else
				s_drv_nx_state = ST_DRV_CLEAR_AWAKE0_DATA;
		end

		ST_DRV_READ_WAIT4: begin
			/* After reading the STATUS REGISTER, which clears the interrupts,
			   wait for the SPI operation to return to IDLE. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_READ_WAIT5;
			else s_drv_nx_state = ST_DRV_READ_WAIT4;
		end

		ST_DRV_READ_WAIT5: begin
			/* Reading the STATUS REGISTER should have cleared INT1 interrupt
			   pin. If it did, transition to state to wait on interrupt.
			   If it did not, try reading the STATUS REGISTER again. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (! ei_int1) s_drv_nx_state = ST_DRV_WAIT_AT_INT2;
			else s_drv_nx_state = ST_DRV_CLEAR_AWAKE0_CMD;
		end

		ST_DRV_WAIT_AT_INT2: begin
			/* If the SOFT RESET command is held, then transition to SOFT RESET operation.
			   If the Interrupt 2 is indicated (Activity status bit), then transition
			   to reading the full measurement of X, Y, Z, Temp.
			   If the Interrupt 1 is indicated (Inactivity status bit), then transition
			   to reading the full measurement of X, Y, Z, Temp.
			   Otherwise, wait for one of these three to occur. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (i_cmd_soft_reset_acl2) s_drv_nx_state = ST_DRV_SOFTRESET_CMD;
			else if (ei_int2) s_drv_nx_state = ST_DRV_READ_ACT0_CMD;
			else if (ei_int1) s_drv_nx_state = ST_DRV_READ_INACT0_CMD;
			else s_drv_nx_state = ST_DRV_WAIT_AT_INT2;
		end

		ST_DRV_READ_ACT0_CMD: begin
			/* Load first byte, command READ, to TX FIFO. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_read;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_readlm_length;
			sdrv.rx_len = c_rx_ax_readlm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b1;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_READ_ACT0_ADDR;
			else
				s_drv_nx_state = ST_DRV_READ_ACT0_CMD;
		end

		ST_DRV_READ_ACT0_ADDR: begin
			/* Load second byte, starting address for Measurements 8-byte sequence, to TX FIFO.
			   At the same time, trigger the SPI bus operation. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_8reg;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_readlm_length;
			sdrv.rx_len = c_rx_ax_readlm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = sdrv.tx_ready;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b1;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = c_rx_ax_readlm_length;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_READ_ACT0_DATA;
			else
				s_drv_nx_state = ST_DRV_READ_ACT0_ADDR;
		end

		ST_DRV_READ_ACT0_DATA: begin
			/* Receive the eight bytes of measurment data from the SPI bus operation,
			   and output the bytes one-at-a-time in a streaming pattern. */
			o_command_ready = 1'b0;
			sdrv.tx_len = c_tx_ax_readlm_length;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.rx_len = c_rx_ax_readlm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = sdrv.rx_avail;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = sdrv.rx_data;
			o_rd_data_byte_valid = sdrv.rx_valid;
			o_rd_data_group_valid = 1'b1;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = sdrv.rx_valid ? (s_byte_index_aux - 1) : s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;			

			if ((sdrv.rx_valid == 1'b1) && (s_byte_index_aux <= 1))
				s_drv_nx_state = ST_DRV_READ_WAIT6;
			else
				s_drv_nx_state = ST_DRV_READ_ACT0_DATA;
		end

		ST_DRV_READ_WAIT6: begin
			/* End the data stream GROUP signal, and wait for the SPI operation
			   to return to IDLE. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_readlm_length;
			sdrv.rx_len = c_rx_ax_readlm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b1;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_CLEAR_AWAKE1_CMD;
			else s_drv_nx_state = ST_DRV_READ_WAIT6;
		end

		ST_DRV_CLEAR_AWAKE1_CMD: begin
			/* Start a clearing of the status register currently indicating
			   ACTIVITY bit.
			   Load the READ command first. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_read;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_clearlm_length;
			sdrv.rx_len = c_rx_ax_clearlm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_CLEAR_AWAKE1_ADDR;
			else
				s_drv_nx_state = ST_DRV_CLEAR_AWAKE1_CMD;
		end

		ST_DRV_CLEAR_AWAKE1_ADDR: begin
			/* Next, load the STATUS REGISTER address and start the SPI
			   bus operation. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_stat;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_clearlm_length;
			sdrv.rx_len = c_rx_ax_clearlm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = sdrv.tx_ready;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = c_rx_ax_clearlm_length;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_CLEAR_AWAKE1_DATA;
			else
				s_drv_nx_state = ST_DRV_CLEAR_AWAKE1_ADDR;
		end

		ST_DRV_CLEAR_AWAKE1_DATA: begin
			/* Receive a new value for the STATUS REGISTER byte. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_clearmm_length;
			sdrv.rx_len = c_rx_ax_clearmm_length;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = sdrv.rx_avail;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'b00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = sdrv.rx_valid ? (s_byte_index_aux - 1) : s_byte_index_aux;
			s_reg_status_val = sdrv.rx_valid ? sdrv.rx_data : s_reg_status_aux;

			if (sdrv.rx_valid)
				s_drv_nx_state = ST_DRV_READ_WAIT7;
			else
				s_drv_nx_state = ST_DRV_CLEAR_AWAKE1_DATA;
		end

		ST_DRV_READ_WAIT7: begin
			/* After reading the STATUS REGISTER, which clears the interrupts,
			   wait for the SPI operation to return to IDLE. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_READ_WAIT8;
			else s_drv_nx_state = ST_DRV_READ_WAIT7;
		end

		ST_DRV_READ_WAIT8: begin
			/* Reading the STATUS REGISTER should have cleared INT2 interrupt
			   pin. If it did, transition to state to wait on interrupt.
			   If it did not, try reading the STATUS REGISTER again. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (! ei_int2) s_drv_nx_state = ST_DRV_WAIT_AT_INT1;
			else s_drv_nx_state = ST_DRV_CLEAR_AWAKE1_CMD;
		end

		ST_DRV_SOFTRESET_CMD: begin
			/* Start the writing of the SOFT RESET byte to the SOFT RESET REGISTER.
			   First, load the WRITE command. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_cmd_write;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_sr_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_SOFTRESET_ADDR;
			else
				s_drv_nx_state = ST_DRV_SOFTRESET_CMD;
		end

		ST_DRV_SOFTRESET_ADDR: begin
			/* Next, load the address of the SOFT RESET REGISTER. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_addr_sr;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_sr_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = c_tx_ax_sr_length - 2;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_SOFTRESET_DATA;
			else
				s_drv_nx_state = ST_DRV_SOFTRESET_ADDR;
		end

		ST_DRV_SOFTRESET_DATA: begin
			/* Finally, load the data value that is command to SOFT RESET,
			   and at the same time trigger the SPI operation to start. */
			o_command_ready = 1'b0;
			sdrv.tx_data = c_adxl362_data_sr;
			sdrv.tx_enqueue = sdrv.tx_ready;
			sdrv.tx_len = c_tx_ax_sr_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = sdrv.tx_ready;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = sdrv.tx_ready ? (s_byte_index_aux - 1) : s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;			

			if (sdrv.tx_ready)
				s_drv_nx_state = ST_DRV_SOFTRESET_WAIT9;
			else
				s_drv_nx_state = ST_DRV_SOFTRESET_DATA;
		end

		ST_DRV_SOFTRESET_WAIT9: begin
			/* Wait for the SPI operation to return to IDLE. Then
			   transition to the BOOT state to reboot the ADXL362. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = c_tx_ax_sr_length;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (sdrv.spi_idle) s_drv_nx_state = ST_DRV_BOOT0;
			else s_drv_nx_state = ST_DRV_SOFTRESET_WAIT9;
		end

		ST_DRV_IDLE1: begin
			/* IDLE the state machine and wait for either a START LINKED MODE
			   or START MESASUREMENT MODE command to transition. If transitioning
			   to LINKED MODE, then wait on Inactivity and then Activity, back
			   and forth. If transitioning to MEASUREMENT MODE, then wait for
			   100 Hz DATA READY interrupt. */
			o_command_ready = sdrv.spi_idle;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (i_cmd_start_linked_mode) s_drv_nx_state = ST_DRV_WAIT_AT_INT1;
			else if (i_cmd_start_measur_mode) s_drv_nx_state =
				ST_DRV_WAIT_DR_INT1;
			else s_drv_nx_state = ST_DRV_IDLE1;
		end

		ST_DRV_IDLE0: begin
			/* IDLE the state machine and wait for either a INIT LINKED MODE
			   or INIT MESASUREMENT MODE command to transition. If transitioning
			   to LINKED MODE, then run the configuration sequence with respective
			   configuration settings. If transitioning to MEASUREMENT MODE, then
			   run the configuration sequence with respective configuration
			   settings. */
			o_command_ready = sdrv.spi_idle;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (i_cmd_init_linked_mode) s_drv_nx_state = ST_DRV_INIT_LM;
			else if (i_cmd_init_measur_mode) s_drv_nx_state = ST_DRV_INIT_MM;
			else s_drv_nx_state = ST_DRV_IDLE0;
		end

		default: begin // ST_DRV_BOOT0
			/* Wait \ref c_t_adx1362_boot time before talking with the ADXL362. */
			o_command_ready = 1'b0;
			sdrv.tx_data = 8'h00;
			sdrv.tx_enqueue = 1'b0;
			sdrv.tx_len = 0;
			sdrv.rx_len = 0;
			sdrv.wait_cyc = 0;
			sdrv.rx_dequeue = 1'b0;
			sdrv.go_stand = 1'b0;
			o_rd_data_stream = 8'h00;
			o_rd_data_byte_valid = 1'b0;
			o_rd_data_group_valid = 1'b0;
			s_tx_ax_cfg0_val = s_tx_ax_cfg0_aux;
			s_tx_ax_cfg1_val = s_tx_ax_cfg1_aux;
			s_tx_ax_cfg2_val = s_tx_ax_cfg2_aux;
			s_tx_ax_cfg3_val = s_tx_ax_cfg3_aux;
			s_tx_ax_cfg4_val = s_tx_ax_cfg4_aux;
			s_tx_ax_cfg5_val = s_tx_ax_cfg5_aux;
			s_byte_index_val = s_byte_index_aux;
			s_reg_status_val = s_reg_status_aux;

			if (s_t == c_t_adxl362_boot - 1) s_drv_nx_state = ST_DRV_IDLE0;
			else s_drv_nx_state = ST_DRV_BOOT0;
		end
	endcase
end : p_fsm_comb

endmodule : pmod_acl2_stand_spi_solo
//------------------------------------------------------------------------------
`end_keywords
