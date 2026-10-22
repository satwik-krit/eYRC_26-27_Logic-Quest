`default_nettype none

module pipe_de (
    input wire clk, reset, FlushE,
    input wire [31:0] WriteData,
    input wire [31:0] RD1,
    input wire [31:0] ImmExt,
    input wire [31:0] PCD,
    input wire [31:0] PCPlus4D,
    input wire [31:0] InstrD,
    input wire [ 3:0] ALUControl,
    input wire [ 2:0] funct3D,
    input wire [ 1:0] ResultSrc,
    input wire [ 1:0] ASrc,
    input wire        RegWrite,
    input wire        Jump,
    input wire        Branch,
    input wire        ALUSrc,
    input wire        Jalr,
    input wire        MemWrite,

    output reg [31:0] RD1E,
    output reg [31:0] ImmExtE,
    output reg [31:0] PCE,
    output reg [31:0] PCPlus4E,
    output reg [31:0] WriteDataE,
    output reg [31:0] InstrE,
    output reg [ 4:0] Rs1E, Rs2E, RdE,
    output reg [ 3:0] ALUControlE,
    output reg [ 2:0] funct3E,
    output reg [ 1:0] ResultSrcE,
    output reg [ 1:0] ASrcE,
    output reg        MemWriteE, RegWriteE, JumpE, BranchE,
    output reg        ALUSrcE,
    output reg        JalrE

);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            RD1E        <= 32'b0;
            ImmExtE     <= 32'b0;
            PCE         <= 32'b0;
            PCPlus4E    <= 32'b0;
            WriteDataE  <= 32'b0;
            InstrE      <= 32'h00000013;
            Rs1E        <= 5'b0;
            Rs2E        <= 5'b0;
            RdE         <= 5'b0;
            ALUControlE <= 4'b0;
            funct3E     <= 3'b0;
            ResultSrcE  <= 2'b0;
            ASrcE       <= 2'b0;
            MemWriteE   <= 1'b0;
            RegWriteE   <= 1'b0;
            JumpE       <= 1'b0;
            BranchE     <= 1'b0;
            ALUSrcE     <= 1'b0;
            JalrE       <= 1'b0;
        end else if (FlushE) begin
            RD1E        <= 32'b0;
            ImmExtE     <= 32'b0;
            PCE         <= 32'b0;
            PCPlus4E    <= 32'b0;
            WriteDataE  <= 32'b0;
            InstrE      <= 32'h00000013;
            Rs1E        <= 5'b0;
            Rs2E        <= 5'b0;
            RdE         <= 5'b0;
            ALUControlE <= 4'b0;
            funct3E     <= 3'b0;
            ResultSrcE  <= 2'b0;
            ASrcE       <= 2'b0;
            MemWriteE   <= 1'b0;
            RegWriteE   <= 1'b0;
            JumpE       <= 1'b0;
            BranchE     <= 1'b0;
            ALUSrcE     <= 1'b0;
            JalrE       <= 1'b0;
        end else begin
            RD1E <= RD1;
            ImmExtE <= ImmExt;
            PCE <= PCD;
            PCPlus4E <= PCPlus4D;
            MemWriteE <=MemWrite;
            RegWriteE <= RegWrite;
            JumpE <= Jump;
            BranchE <= Branch;
            ResultSrcE <= ResultSrc;
            ASrcE <= ASrc;
            ALUSrcE <= ALUSrc;
            JalrE <= Jalr;
            ALUControlE <= ALUControl;
            WriteDataE <= WriteData;
            Rs1E <= InstrD[19:15];
            Rs2E <= InstrD[24:20];
            RdE  <= InstrD[11:7];
            InstrE <= InstrD;
            funct3E <= funct3D;
        end
    end

endmodule
