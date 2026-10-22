`default_nettype none

module pipe_mw (
    input wire clk, reset,
    input wire [31:0] ALUResultM,
    input wire [31:0] FormattedReadData,
    input wire [ 4:0] RdM,
    input wire [31:0] PCPlus4M,
    input wire [31:0] WriteDataM,
    input wire [ 2:0] funct3M,
    input wire [ 1:0] ResultSrcM,
    input wire        RegWriteM,

    output reg [31:0] ALUResultW,
    output reg [31:0] ReadDataW,
    output reg [ 4:0] RdW,
    output reg [31:0] PCPlus4W,
    output reg [31:0] WriteDataW,
    output reg [ 2:0] funct3W,
    output reg [ 1:0] ResultSrcW,
    output reg        RegWriteW
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ALUResultW <= 32'b0;
            ReadDataW  <= 32'b0;
            RdW        <= 5'b0;
            PCPlus4W   <= 32'b0;
            ResultSrcW <= 2'b0;
            RegWriteW  <= 1'b0;
            WriteDataW <= 32'b0;
            funct3W    <= 3'b0;
        end else begin
            ALUResultW <= ALUResultM;
            ReadDataW <= FormattedReadData;
            RdW <= RdM;
            PCPlus4W <= PCPlus4M;
            ResultSrcW <= ResultSrcM;
            RegWriteW <= RegWriteM;
            WriteDataW<= WriteDataM;
            funct3W <= funct3M;
        end
    end

endmodule
