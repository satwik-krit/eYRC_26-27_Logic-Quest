`default_nettype none

module pipe_em (
    input wire clk, reset,
    input wire [31:0] WriteDataE,
    input wire [31:0] ALUResult,
    input wire [31:0] PCPlus4E,
    input wire [ 4:0] RdE,
    input wire [ 2:0] funct3E,
    input wire [ 1:0] ResultSrcE,
    input wire        RegWriteE,
    input wire        MemWriteE,

    output reg [31:0] ALUResultM,
    output reg [31:0] PCPlus4M,
    output reg [31:0] WriteDataM,
    output reg [ 4:0] RdM,
    output reg [ 2:0] funct3M,
    output reg [ 1:0] ResultSrcM,
    output reg        RegWriteM,
    output reg        MemWriteM
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ALUResultM <= 32'b0;
            WriteDataM <= 32'b0;
            PCPlus4M   <= 32'b0;
            RdM        <= 5'b0;
            ResultSrcM <= 2'b0;
            RegWriteM  <= 1'b0;
            MemWriteM  <= 1'b0;
            funct3M    <= 3'b0;
        end else begin
            ALUResultM <= ALUResult;
            WriteDataM <= WriteDataE;
            PCPlus4M <= PCPlus4E;
            RdM <= RdE;
            ResultSrcM <= ResultSrcE;
            RegWriteM <= RegWriteE;
            MemWriteM <= MemWriteE;
            funct3M <= funct3E;
        end
    end

endmodule
