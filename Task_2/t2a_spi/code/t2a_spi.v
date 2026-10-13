/*
eYRC26-27: Logic Quest
Task 2A: SPI Master Module
Description : Parameterizable SPI master controller supporting all 4 SPI
              modes (via CPOL/CPHA), configurable bit order (MSB/LSB
              first), and configurable word length. Derives SCLK by
              dividing down the 50MHz input clock (HALF_PERIOD sets the
              divide ratio). On `start`, shifts tx_data out on MOSI while
              simultaneously shifting MISO into rx_data; `busy` is high
              for the duration and `cs_out` is driven low for the transfer.
Parameters:
  CPOL             - Clock polarity (0: idle low, 1: idle high)        [default: 0]
  CPHA             - Clock phase (0: sample leading edge,
                      1: sample trailing edge)                        [default: 0]
  LSB_FIRST        - Bit order (0: MSB first, 1: LSB first)           [default: 0]
  SPI_WORD_LENGTH  - Number of bits per transfer                      [default: 8]
  HALF_PERIOD      - clk_50MHz cycles per SCLK half-period.
                      SCLK freq = 50MHz / (2 x HALF_PERIOD)           [default: 25 -> 1MHz]
Ports:
  clk_50MHz    (in )  1 bit               - System clock (50MHz)
  rst_n        (in )  1 bit               - Active-low async reset
  start        (in )  1 bit               - Pulse high (sampled in IDLE) to begin transfer
  tx_data      (in )  SPI_WORD_LENGTH     - Data word to transmit on MOSI
  miso_input   (in )  1 bit               - Serial data in from SPI slave
  sclk_out     (out)  1 bit               - SPI serial clock, idles at CPOL
  cs_out       (out)  1 bit               - Chip select, active-low during transfer
  mosi_output  (out)  1 bit               - Serial data out to SPI slave
  rx_data      (out)  SPI_WORD_LENGTH     - Data received from MISO (valid once busy=0)
  busy         (out)  1 bit               - High for the duration of an active transfer
*/

module t2a_spi
#(
    parameter CPOL             = 1'b0,
    parameter CPHA             = 1'b0,
    parameter LSB_FIRST        = 1'b0,
    parameter SPI_WORD_LENGTH  = 8,
    parameter HALF_PERIOD      = 25   // clk_50MHz cycles per half sclk period
)
(
    input wire clk_50MHz,
    input wire rst_n,

    input wire start,
    input wire [SPI_WORD_LENGTH-1:0] tx_data,
    input wire miso_input,

    output reg sclk_out,
    output reg cs_out,
    output reg mosi_output,

    output reg [SPI_WORD_LENGTH-1:0] rx_data,
    output reg busy
);

//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE //////////////////

   localparam S_IDLE = 0;
   localparam S_TRANSFER = 1;
   localparam S_DONE = 2;

   reg [1:0] state = S_IDLE, next_state;

   reg [$clog2(2*HALF_PERIOD-1):0] cycle_counter;
   reg [$clog2(SPI_WORD_LENGTH-1):0] bit_counter;

   // Transmit and recieve shift registers
   reg [SPI_WORD_LENGTH-1:0] trans, recv;

   wire current_tx_bit = (LSB_FIRST) ? trans[bit_counter + 1'b1] : trans[SPI_WORD_LENGTH - 2 - bit_counter];

   wire sclk_leading_edge  = (cycle_counter == HALF_PERIOD - 1);
   wire sclk_trailing_edge = (cycle_counter == 2 * HALF_PERIOD - 1);

   wire sample_edge = (CPHA == 0) ? sclk_leading_edge : sclk_trailing_edge;
   wire drive_edge  = (CPHA == 0) ? sclk_trailing_edge : sclk_leading_edge;

   wire transfer_complete = (bit_counter == SPI_WORD_LENGTH - 1) && (cycle_counter == 2 * HALF_PERIOD - 1);

   always @(posedge clk_50MHz or negedge rst_n) begin
       if (!rst_n) state <= S_IDLE;
       else state <= next_state;
   end

   always @(*) begin
       next_state = state;
       case (state)
        S_IDLE: begin
            if (start == 1) next_state = S_TRANSFER;
        end

        S_TRANSFER: begin
            if (transfer_complete) next_state = S_DONE;
            else next_state = S_TRANSFER;
        end

        S_DONE:  next_state = S_IDLE;

        default: next_state = S_IDLE;
       endcase
   end

   always @(posedge clk_50MHz or negedge rst_n) begin
       if (rst_n == 0) begin
            cs_out <= 1;
            busy <= 0;
            mosi_output <= 1'bx;
            sclk_out <= CPOL;
            rx_data <= 0;
            trans <= 0;
            recv <= 0;
            cycle_counter <= 0;
            bit_counter <= 0;
       end

       else case (state)
           S_IDLE: begin
               cs_out <= 1;
               sclk_out <= CPOL;
               busy <= 0;
               mosi_output <= 1'bx;

               if (start == 1) begin
                // Capture data for transfer. tx_data is now
                // free to change during the transfer as well.
                trans <= tx_data;


                // For mode 0, we need to write the first bit to
                // MOSI so that the first rising edge has something to sample from.
                mosi_output <= (LSB_FIRST) ? tx_data[0] : tx_data[SPI_WORD_LENGTH - 1];

                // Reset counters and recieving register.
                recv <= 0;
                cycle_counter <= 0;
                bit_counter <= 0;
               end
           end

           S_TRANSFER: begin
               cs_out <= 0;
               busy <= 1;

               if (sample_edge) begin
                   recv <= (LSB_FIRST) ? {miso_input, recv[SPI_WORD_LENGTH-1:1]}
                                       : {recv[SPI_WORD_LENGTH-2:0], miso_input};
               end

               if (drive_edge) begin
                   bit_counter <= bit_counter + 1'b1;

                   if (bit_counter < SPI_WORD_LENGTH - 1) begin
                       mosi_output <= current_tx_bit;
                   end
               end

               if (cs_out == 1'b1) cycle_counter <= 0;
               else if (sclk_trailing_edge)  cycle_counter <= 0;
               else cycle_counter <= cycle_counter + 1'b1;

               if (transfer_complete) begin
                   rx_data <= recv;
               end

               sclk_out <= CPOL ^ (cycle_counter >= HALF_PERIOD);

           end

           S_DONE: begin
               cs_out <= 1;
               busy <= 0;
               mosi_output <= 1'bx;
               sclk_out <= CPOL;
           end

           default: ;
       endcase
   end

//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE //////////////////

endmodule
