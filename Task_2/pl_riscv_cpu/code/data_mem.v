
// data_mem.v - data memory

`default_nettype none

module data_mem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MEM_SIZE = 64
) (
    input wire clk,
    input wire wr_en,
    input wire [2:0] funct3,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data,
    output reg [DATA_WIDTH-1:0] rd_data_mem
);

// array of 64 32-bit data
reg [DATA_WIDTH-1:0] data_ram [0:MEM_SIZE-1];

wire [ADDR_WIDTH-1:0] word_addr = wr_addr[DATA_WIDTH-1:2] % 64;

// Synchronous write logic
always @(posedge clk) begin
    if (wr_en) begin
        case (funct3)

            3'b000: begin // SB: store byte
                case (wr_addr[1:0])
                    2'b00: data_ram[word_addr][7:0]   <= wr_data[7:0];
                    2'b01: data_ram[word_addr][15:8]  <= wr_data[7:0];
                    2'b10: data_ram[word_addr][23:16] <= wr_data[7:0];
                    2'b11: data_ram[word_addr][31:24] <= wr_data[7:0];
                endcase
            end

            3'b001: begin // SH: store halfword
                if (wr_addr[1] == 1'b0)
                    data_ram[word_addr][15:0] <= wr_data[15:0];
                else
                    data_ram[word_addr][31:16] <= wr_data[15:0];
            end

            3'b010: begin // SW: store word
                data_ram[word_addr] <= wr_data;
            end

        endcase
    end
end

always @(*) begin
    case (funct3)
        3'b000: begin // lb
            case (wr_addr[1:0])
                2'b00: rd_data_mem = {{24{data_ram[word_addr][ 7]}}, data_ram[word_addr][ 7: 0]};
                2'b01: rd_data_mem = {{24{data_ram[word_addr][15]}}, data_ram[word_addr][15: 8]};
                2'b10: rd_data_mem = {{24{data_ram[word_addr][23]}}, data_ram[word_addr][23:16]};
                2'b11: rd_data_mem = {{24{data_ram[word_addr][31]}}, data_ram[word_addr][31:24]};
            endcase
        end
        3'b100: begin // lbu
            case (wr_addr[1:0])
                2'b00: rd_data_mem = {24'b0, data_ram[word_addr][ 7: 0]};
                2'b01: rd_data_mem = {24'b0, data_ram[word_addr][15: 8]};
                2'b10: rd_data_mem = {24'b0, data_ram[word_addr][23:16]};
                2'b11: rd_data_mem = {24'b0, data_ram[word_addr][31:24]};
            endcase
        end
		  
		  
		  
		  3'b001: begin // LH: signed halfword load
    if (wr_addr[1] == 1'b0)
        rd_data_mem = {
            {16{data_ram[word_addr][15]}},
            data_ram[word_addr][15:0]
        };
    else
        rd_data_mem = {
            {16{data_ram[word_addr][31]}},
            data_ram[word_addr][31:16]
        };
end

3'b101: begin // LHU: unsigned halfword load
    if (wr_addr[1] == 1'b0)
        rd_data_mem = {
            16'b0,
            data_ram[word_addr][15:0]
        };
    else
        rd_data_mem = {
            16'b0,
            data_ram[word_addr][31:16]
        }; //adding the LH  and LHU cases as necessary for functionality in the testbench
end
		  
		  		  
		  
        3'b010: rd_data_mem = data_ram[word_addr]; // lw
        default: rd_data_mem = 32'bx;
    endcase
end

endmodule
`default_nettype wire
