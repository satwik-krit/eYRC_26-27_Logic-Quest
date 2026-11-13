// data_mem.v - data memory

`default_nettype none

module data_mem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MEM_SIZE = 128
) (
    input wire clk,
    input wire wr_en,
    input wire [2:0] funct3,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data,
    output reg [DATA_WIDTH-1:0] rd_data_mem
);

// array of 128 32-bit data - the actual storage block
reg [DATA_WIDTH-1:0] data_ram [0:MEM_SIZE-1];

// Initialising BRAM to 0 at startup
integer i;
initial begin
    for (i = 0; i < MEM_SIZE; i = i + 1)
        data_ram[i] = 32'b0;
end

// Since we only have 128 words in memory, 7 bits are enough
// to index every word in the array.
// Clean bit slices map directly to BRAM's pins, requiring no extra
// logic.
//
// [1:0] - go into the byte-enable decoder to decide which byte of the word we want
// [8:2] - 7 bits to uniquely index a word
// remaining bits are unnecessary
wire [6:0] word_addr = wr_addr[8:2];

// Intermediate register for data read from
reg [DATA_WIDTH-1:0] read_data;
reg [2:0] funct3_reg;
reg [1:0] wr_addr_reg;

always @(posedge clk) begin
    read_data       <= data_ram[word_addr];
    funct3_reg      <= funct3;
    wr_addr_reg <= wr_addr[1:0];
end

reg [3:0]  byte_en;
reg [31:0] write_data_aligned;

always @(*) begin
    // Defaults prevent latches and ensure no accidental writes
    byte_en = 4'b0000;
    write_data_aligned = wr_data;

    if (wr_en) begin
        case (funct3)
            3'b000: begin // SB: Replicate lowest byte to all 4 lanes
                write_data_aligned = {4{wr_data[7:0]}};
                case (wr_addr[1:0])
                    2'b00: byte_en = 4'b0001;
                    2'b01: byte_en = 4'b0010;
                    2'b10: byte_en = 4'b0100;
                    2'b11: byte_en = 4'b1000;
                endcase
            end

            3'b001: begin // SH: Replicate lower halfword to both halves
                write_data_aligned = {2{wr_data[15:0]}};
                byte_en = (wr_addr[1] == 1'b0) ? 4'b0011 : 4'b1100;
            end

            3'b010: begin // SW: Enable all 4 lanes
                write_data_aligned = wr_data;
                byte_en = 4'b1111;
            end

            default: byte_en = 4'b0000;
        endcase
    end
end


always @(posedge clk) begin
    if (byte_en[0]) data_ram[word_addr][7:0]   <= write_data_aligned[7:0];
    if (byte_en[1]) data_ram[word_addr][15:8]  <= write_data_aligned[15:8];
    if (byte_en[2]) data_ram[word_addr][23:16] <= write_data_aligned[23:16];
    if (byte_en[3]) data_ram[word_addr][31:24] <= write_data_aligned[31:24];
end

always @(*) begin
    case (funct3_reg)
        3'b000: begin // lb
            case (wr_addr_reg[1:0])
                2'b00: rd_data_mem = {{24{read_data[ 7]}}, read_data[ 7: 0]};
                2'b01: rd_data_mem = {{24{read_data[15]}}, read_data[15: 8]};
                2'b10: rd_data_mem = {{24{read_data[23]}}, read_data[23:16]};
                2'b11: rd_data_mem = {{24{read_data[31]}}, read_data[31:24]};
            endcase
        end
        3'b100: begin // lbu
            case (wr_addr_reg[1:0])
                2'b00: rd_data_mem = {24'b0, read_data[ 7: 0]};
                2'b01: rd_data_mem = {24'b0, read_data[15: 8]};
                2'b10: rd_data_mem = {24'b0, read_data[23:16]};
                2'b11: rd_data_mem = {24'b0, read_data[31:24]};
            endcase
        end



		  3'b001: begin // LH: signed halfword load
            if (wr_addr_reg[1] == 1'b0)
                rd_data_mem = {
                    {16{read_data[15]}},
                    read_data[15:0]
                };
            else
                rd_data_mem = {
                    {16{read_data[31]}},
                    read_data[31:16]
                };
        end

        3'b101: begin // LHU: unsigned halfword load
            if (wr_addr_reg[1] == 1'b0)
                rd_data_mem = {
                    16'b0,
                    read_data[15:0]
                };
            else
                rd_data_mem = {
                    16'b0,
                    read_data[31:16]
                }; //adding the LH  and LHU cases as necessary for functionality in the testbench
        end



        3'b010: rd_data_mem = read_data; // lw
        default: rd_data_mem = 32'b0;
    endcase
end

endmodule
`default_nettype wire
