// instr_mem.v - instruction memory

`default_nettype none

module instr_mem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MEM_SIZE   = 1024
) (
    input  wire                  clk,
    input  wire                  en,
    input  wire [ADDR_WIDTH-1:0] instr_addr,
    output reg  [DATA_WIDTH-1:0] instr
);

// array of 1024 32-bit words or instructions (4 KB)
reg [DATA_WIDTH-1:0] instr_ram [0:MEM_SIZE-1];

initial begin
    $readmemh("program.hex", instr_ram);
end

// Synchronous BRAM read (10-bit word address for 1024 words)
always @(posedge clk) begin
    if (en)
        instr <= instr_ram[instr_addr[11:2]];
end

endmodule

`default_nettype wire
