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
-- \file uart_tx_only.v
--
-- \brief A simplified UART function to drive TX characters on a UART board
--        connection, independent of any RX function (presumed to be ingored).
--        Maximum baudrate is 115200; input clock is 7.37 MHz to support divison
--        to modem clock rates.
------------------------------------------------------------------------------*/
//Recursive Moore Machine-------------------------------------------------------
//Part 1: Module header:--------------------------------------------------------
module uart_tx_only(
    i_clk_20mhz, i_rst_20mhz,
    i_clk_7_37mhz, i_rst_7_37mhz,
    eo_uart_tx,
    i_tx_data, i_tx_valid, o_tx_ready
    );

parameter BAUD = 115200;

// system clock
input wire i_clk_20mhz;
input wire i_rst_20mhz;

// modem clock from MMCM divided down
input wire i_clk_7_37mhz;
input wire i_rst_7_37mhz;

// the output to connect to USB-UART RXD pin
output reg eo_uart_tx;

// data to transmit out the UART
input wire [7:0] i_tx_data;
input wire i_tx_valid;

// indication that the FIFO is not almost full and can receive a line of data
output wire o_tx_ready;

//Part 2: Declarations----------------------------------------------------------

// State Machine constants and variables
`define c_uarttxonly_fsm_state_bits 2

localparam [(`c_uarttxonly_fsm_state_bits - 1):0] ST_IDLE = 0;
localparam [(`c_uarttxonly_fsm_state_bits - 1):0] ST_START = 1;
localparam [(`c_uarttxonly_fsm_state_bits - 1):0] ST_DATA = 2;
localparam [(`c_uarttxonly_fsm_state_bits - 1):0] ST_STOP = 3;

// State machine state register
// Xilinx state machine register attributes
(* fsm_encoding = "gray" *)
(* fsm_safe_state = "default_state" *)
reg [(`c_uarttxonly_fsm_state_bits - 1):0] s_uarttxonly_pr_state;
reg [(`c_uarttxonly_fsm_state_bits - 1):0] s_uarttxonly_nx_state;

// State machine output and auxiliary registers
reg so_uart_tx;
reg [3:0] s_i_val;
reg [3:0] s_i_aux;
reg [7:0] s_data_val;
reg [7:0] s_data_aux;

// internal clock for 1x the baud rate
wire s_ce_baud_1x;

// Mapping for FIFO TX
wire [7:0] s_data_fifo_tx_in;
wire [7:0] s_data_fifo_tx_out;
reg s_data_fifo_tx_re;
wire s_data_fifo_tx_we;
wire s_data_fifo_tx_full;
wire s_data_fifo_tx_empty;
reg s_data_fifo_tx_valid;
wire [10:0] s_data_fifo_tx_wr_count;
wire [10:0] s_data_fifo_tx_rd_count;
wire s_data_fifo_tx_almostempty;
wire s_data_fifo_tx_almostfull;
wire s_data_fifo_tx_rd_err;
wire s_data_fifo_tx_wr_err;

//Part 3: Statements------------------------------------------------------------

// clock enable for 1x times the baud rate: no oversampling for TX ONLY
clock_enable_divider #(.par_ce_divisor(4 * 16 * 115200 / BAUD))
    u_baud_1x_ce_divider (
    .o_ce_div(s_ce_baud_1x),
    .i_clk_mhz(i_clk_7_37mhz),
    .i_rst_mhz(i_rst_7_37mhz),
    .i_ce_mhz(1'b1));

// FIFO to receive from system and gradually transmit to UART.
// The FIFO must implement read-ahead output on rd_en.
assign s_data_fifo_tx_in = i_tx_data;
assign s_data_fifo_tx_we = i_tx_valid;
assign o_tx_ready = ((! s_data_fifo_tx_full) && (! s_data_fifo_tx_almostfull));

always @(posedge i_clk_7_37mhz)
begin: p_gen_fifo_tx_valid
    s_data_fifo_tx_valid <= s_data_fifo_tx_re;
end

// FIFO_DUALCLOCK_MACRO: Dual Clock First-In, First-Out (FIFO) RAM Buffer
//                       Artix-7
// Xilinx HDL Language Template, version 2019.1

/////////////////////////////////////////////////////////////////
// DATA_WIDTH | FIFO_SIZE | FIFO Depth | RDCOUNT/WRCOUNT Width //
// ===========|===========|============|=======================//
//   37-72    |  "36Kb"   |     512    |         9-bit         //
//   19-36    |  "36Kb"   |    1024    |        10-bit         //
//   19-36    |  "18Kb"   |     512    |         9-bit         //
//   10-18    |  "36Kb"   |    2048    |        11-bit         //
//   10-18    |  "18Kb"   |    1024    |        10-bit         //
//    5-9     |  "36Kb"   |    4096    |        12-bit         //
//    5-9     |  "18Kb"   |    2048    |        11-bit         //
//    1-4     |  "36Kb"   |    8192    |        13-bit         //
//    1-4     |  "18Kb"   |    4096    |        12-bit         //
/////////////////////////////////////////////////////////////////

FIFO_DUALCLOCK_MACRO  #(
  .ALMOST_EMPTY_OFFSET(11'h022), // Sets the almost empty threshold
  .ALMOST_FULL_OFFSET(11'h7de),  // Sets almost full threshold
  .DATA_WIDTH(8),   // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
  .DEVICE("7SERIES"),  // Target device: "7SERIES"
  .FIFO_SIZE ("18Kb"), // Target BRAM: "18Kb" or "36Kb"
  .FIRST_WORD_FALL_THROUGH ("TRUE") // Sets the FIFO FWFT to "TRUE" or "FALSE"
) u_fifo_uart_tx_0 (
  .ALMOSTEMPTY(s_data_fifo_tx_almostempty), // 1-bit output almost empty
  .ALMOSTFULL(s_data_fifo_tx_almostfull),   // 1-bit output almost full
  .DO(s_data_fifo_tx_out),                  // Output data, width defined by DATA_WIDTH parameter
  .EMPTY(s_data_fifo_tx_empty),             // 1-bit output empty
  .FULL(s_data_fifo_tx_full),               // 1-bit output full
  .RDCOUNT(s_data_fifo_tx_rd_count),        // Output read count, width determined by FIFO depth
  .RDERR(s_data_fifo_tx_rd_err),            // 1-bit output read error
  .WRCOUNT(s_data_fifo_tx_wr_count),        // Output write count, width determined by FIFO depth
  .WRERR(s_data_fifo_tx_wr_err),            // 1-bit output write error
  .DI(s_data_fifo_tx_in),                   // Input data, width defined by DATA_WIDTH parameter
  .RDCLK(i_clk_7_37mhz),                    // 1-bit input read clock
  .RDEN(s_data_fifo_tx_re),                 // 1-bit input read enable
  .RST(i_rst_7_37mhz),                      // 1-bit input reset
  .WRCLK(i_clk_20mhz),                      // 1-bit input write clock
  .WREN(s_data_fifo_tx_we)                  // 1-bit input write enable
);

// End of FIFO_DUALCLOCK_MACRO_inst instantiation


// FSM register and auxiliary registers
always @(posedge i_clk_7_37mhz)
begin: p_uarttxonly_fsm_state_aux
    if (i_rst_7_37mhz) begin
        s_uarttxonly_pr_state <= ST_IDLE;

        s_i_aux <= 0;
        s_data_aux <= 8'h00;
    end else if (s_ce_baud_1x) begin
        s_uarttxonly_pr_state <= s_uarttxonly_nx_state;

        s_i_aux <= s_i_val;
        s_data_aux <= s_data_val;
    end
end

// FSM combinatorial logic with output and auxiliary registers
always @(s_uarttxonly_pr_state,
    s_data_fifo_tx_empty,
    s_i_aux, s_data_aux,
    s_data_fifo_tx_out,
    s_ce_baud_1x)
begin: p_uarttxonly_fsm_nx_out
    case (s_uarttxonly_pr_state)
        ST_START: begin
            // Transmit the UART serial START bit '0' and load the
            // next TX FIFO byte on transition.
            s_data_fifo_tx_re = s_ce_baud_1x;
            s_data_val = s_data_fifo_tx_out;
            s_i_val = 0;

            so_uart_tx = 1'b0;

            s_uarttxonly_nx_state = ST_DATA;
        end
        ST_DATA: begin
            // Transmit the byte data to UART serial, least significant
            // bit first, index 0 to 7.
            s_data_fifo_tx_re = 1'b0;
            s_data_val = s_data_aux;
            s_i_val = s_i_aux + 1;

            // output by mux instead of shifting
            so_uart_tx = s_data_aux[s_i_aux];

            if (s_i_aux == 7) s_uarttxonly_nx_state = ST_STOP;
            else s_uarttxonly_nx_state = ST_DATA;
        end
        ST_STOP: begin
            // Transmit the UART serial STOP bit '1'. Check the FIFO
            // status. If FIFO contains more data, then transition
            // directly back to the START bit. This prevents breaks of time
            // between sending bytes, when there is already more data to
            // send. Otherwise, transition to the IDLE state.
            s_data_fifo_tx_re = 1'b0;
            s_data_val = s_data_aux;
            s_i_val = s_i_aux;

            so_uart_tx = 1'b1;

            if (! s_data_fifo_tx_empty) s_uarttxonly_nx_state = ST_START;
            else s_uarttxonly_nx_state = ST_IDLE;
        end
        default: begin // ST_IDLE
            // The IDLE state holds a continuous high value on the
            // serial line to indicate UART signal is IDLE.
            s_data_fifo_tx_re = 1'b0;
            s_data_val = s_data_aux;
            s_i_val = s_i_aux;

            so_uart_tx = 1'b1;

            if (! s_data_fifo_tx_empty) s_uarttxonly_nx_state = ST_START;
            else s_uarttxonly_nx_state = ST_IDLE;
        end
    endcase
end

// Registered output for timing closure and glitch removal on the output pin
always @(posedge i_clk_7_37mhz)
begin: p_fsm_out_reg
    if (i_rst_7_37mhz) eo_uart_tx <= 1'b1;
    else if (s_ce_baud_1x) eo_uart_tx <= so_uart_tx;
end

endmodule
//------------------------------------------------------------------------------
