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
-- \file pmod_cls_custom_driver.v
--
-- \brief A wrapper for the single Chip Select, Standard SPI modules
--        \ref pmod_cls_stand_spi_solo and \ref pmod_generic_spi_solo ,
--        implementing a custom single-mode operation of the PMOD CLS by
--        Digilent Inc.
------------------------------------------------------------------------------*/
//------------------------------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module pmod_cls_custom_driver (
	/* Clock and reset, with clock at 32 times the frequency of the SPI bus,
	   with a clock enable that is 4 times the frequency of the SPI bus. */
	i_clk_20mhz, i_rst_20mhz, i_ce_2_5mhz,
	/* Outputs and inputs from the single SPI peripheral */
	eo_sck_t, eo_sck_o, eo_csn_t, eo_csn_o, eo_copi_t, eo_copi_o,
	ei_cipo,
	/* Command ready indication and five possible commands to the driver */
	o_command_ready,
	i_cmd_wr_clear_display,
	i_cmd_wr_text_line1,
	i_cmd_wr_text_line2,
	i_dat_ascii_line1,
	i_dat_ascii_line2);

/* Disable or enable fast FSM delays for simulation instead of impelementation. */
parameter integer parm_fast_simulation = 0;
/* Actual frequency in Hz of \ref i_ce_2_5mhz */
parameter integer FCLK = 20000000;
/* Clock enable frequency in Hz of \ref i_ext_spi_clk_4x with i_spi_ce_4x */
parameter integer FCLK_ce = 2500000;
/* Ratio of i_ext_spi_clk_x to SPI sck bus output. */
parameter parm_ext_spi_clk_ratio = 32;
/* LOG2 of the TX FIFO max count */
parameter parm_tx_len_bits = 11;
/* LOG2 of max Wait Cycles count between end of TX and start of RX */
parameter parm_wait_cyc_bits = 2;
/* LOG2 of the RX FIFO max count */
parameter parm_rx_len_bits = 11;

input wire i_clk_20mhz;
input wire i_rst_20mhz;
input wire i_ce_2_5mhz;

output reg eo_sck_t;
output reg eo_sck_o;
output reg eo_csn_t;
output reg eo_csn_o;
output reg eo_copi_t;
output reg eo_copi_o;
input wire ei_cipo;

output wire o_command_ready;
input wire i_cmd_wr_clear_display;
input wire i_cmd_wr_text_line1;
input wire i_cmd_wr_text_line2;
input wire [127:0] i_dat_ascii_line1;
input wire [127:0] i_dat_ascii_line2;

//Part 2: Declarations----------------------------------------------------------
/* CLS SPI driver wiring to the Generic SPI driver. */
wire s_cls_go_stand;
wire s_cls_spi_idle;
wire [(parm_tx_len_bits - 1):0] s_cls_tx_len;
wire [(parm_wait_cyc_bits - 1):0] s_cls_wait_cyc;
wire [(parm_rx_len_bits - 1):0] s_cls_rx_len;
wire [7:0] s_cls_tx_data;
wire s_cls_tx_enqueue;
wire s_cls_tx_ready;
wire [7:0] s_cls_rx_data;
wire s_cls_rx_dequeue;
wire s_cls_rx_valid;
wire s_cls_rx_avail;

/* CLS SPI outputs, FSM signals to register the SPI bus outputs for
   optimal timing closure and glitch minimization. */
wire sio_cls_sck_fsm_o;
wire sio_cls_sck_fsm_t;
wire sio_cls_csn_fsm_o;
wire sio_cls_csn_fsm_t;
wire sio_cls_copi_fsm_o;
wire sio_cls_copi_fsm_t;

/* CLS SPI input synchronizer signals, where the synchronizer is used to
   mitigate metastability. */
reg sio_cls_cipo_meta_i;
reg sio_cls_cipo_sync_i;

//Part 3: Statements------------------------------------------------------------

/* Register the SPI output an extra 4x-SPI-clock clock cycle for better
   timing closure and glitch mitigation. */
always @(posedge i_clk_20mhz)
begin: p_reg_spi_fsm_out
	if (i_ce_2_5mhz) begin
		eo_sck_o <= sio_cls_sck_fsm_o;
		eo_sck_t <= sio_cls_sck_fsm_t;

		eo_csn_o <= sio_cls_csn_fsm_o;
		eo_csn_t <= sio_cls_csn_fsm_t;

		eo_copi_o <= sio_cls_copi_fsm_o;
		eo_copi_t <= sio_cls_copi_fsm_t;
	end
end

/* Double-register the SPI input at 4x-SPI-clock cycle to prevent metastability. */
always @(posedge i_clk_20mhz)
begin: p_sync_spi_in
	if (i_ce_2_5mhz) begin
		sio_cls_cipo_sync_i <= sio_cls_cipo_meta_i;
		sio_cls_cipo_meta_i <= ei_cipo;
	end
end

/* Single mode driver to operate the PMOD CLS via a stand-alone SPI driver. */
pmod_cls_stand_spi_solo #(
	.parm_fast_simulation(parm_fast_simulation),
	.FCLK (FCLK),
	.FCLK_ce (FCLK_ce),
	.parm_tx_len_bits (parm_tx_len_bits),
	.parm_wait_cyc_bits(parm_wait_cyc_bits),
	.parm_rx_len_bits (parm_rx_len_bits)
	) u_pmod_cls_stand_spi_solo (
	.i_ext_spi_clk_x(i_clk_20mhz),
	.i_srst(i_rst_20mhz),
	.i_spi_ce_4x(i_ce_2_5mhz),
	.o_go_stand(s_cls_go_stand),
	.i_spi_idle(s_cls_spi_idle),
	.o_tx_len(s_cls_tx_len),
	.o_wait_cyc(s_cls_wait_cyc),
	.o_rx_len(s_cls_rx_len),
	.o_tx_data(s_cls_tx_data),
	.o_tx_enqueue(s_cls_tx_enqueue),
	.i_tx_ready(s_cls_tx_ready),
	.i_rx_data(s_cls_rx_data),
	.o_rx_dequeue(s_cls_rx_dequeue),
	.i_rx_valid(s_cls_rx_valid),
	.i_rx_avail(s_cls_rx_avail),
	.o_command_ready(o_command_ready),
	.i_cmd_wr_clear_display(i_cmd_wr_clear_display),
	.i_cmd_wr_text_line1(i_cmd_wr_text_line1),
	.i_cmd_wr_text_line2(i_cmd_wr_text_line2),
	.i_dat_ascii_line1(i_dat_ascii_line1),
	.i_dat_ascii_line2(i_dat_ascii_line2));

/* Stand-alone SPI bus driver for a single bus-peripheral. */
pmod_generic_spi_solo #(
	.parm_ext_spi_clk_ratio (parm_ext_spi_clk_ratio),
	.parm_tx_len_bits  (parm_tx_len_bits),
	.parm_wait_cyc_bits (parm_wait_cyc_bits),
	.parm_rx_len_bits  (parm_rx_len_bits)
	) u_pmod_generic_spi_solo (
	.eo_sck_o(sio_cls_sck_fsm_o),
	.eo_sck_t(sio_cls_sck_fsm_t),
	.eo_csn_o(sio_cls_csn_fsm_o),
	.eo_csn_t(sio_cls_csn_fsm_t),
	.eo_copi_o(sio_cls_copi_fsm_o),
	.eo_copi_t(sio_cls_copi_fsm_t),
	.ei_cipo_i(sio_cls_cipo_sync_i),
	.i_ext_spi_clk_x(i_clk_20mhz),
	.i_srst(i_rst_20mhz),
	.i_spi_ce_4x(i_ce_2_5mhz),
	.i_go_stand(s_cls_go_stand),
	.o_spi_idle(s_cls_spi_idle),
	.i_tx_len(s_cls_tx_len),
	.i_wait_cyc(s_cls_wait_cyc),
	.i_rx_len(s_cls_rx_len),
	.i_tx_data(s_cls_tx_data),
	.i_tx_enqueue(s_cls_tx_enqueue),
	.o_tx_ready(s_cls_tx_ready),
	.o_rx_data(s_cls_rx_data),
	.i_rx_dequeue(s_cls_rx_dequeue),
	.o_rx_valid(s_cls_rx_valid),
	.o_rx_avail(s_cls_rx_avail));

endmodule
//------------------------------------------------------------------------------
