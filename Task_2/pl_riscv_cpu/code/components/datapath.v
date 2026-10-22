`default_nettype none

module datapath (
    input  wire        clk, reset,
    input  wire [1:0]  ResultSrc,
    input  wire        ALUSrc, RegWrite,
    input  wire [2:0]  ImmSrc,
    input  wire [3:0]  ALUControl,
    input  wire [1:0]  ASrc,
    input  wire        Branch, Jump, Jalr, MemWrite,
    input  wire [31:0] Instr, ReadData,

    output wire [31:0] PC,
    output wire [31:0] Mem_WrAddr, Mem_WrData,
    output wire [31:0] Result,
    output wire [31:0] PCW, ALUResultW, WriteDataW,
    output wire [31:0] InstrD,
    output wire [ 2:0] funct3,
    output wire        MemWriteM
);

    // Hazard Unit Wires (Placeholders)
    wire StallF = 1'b0;
    wire StallD = 1'b0;
    wire FlushD = 1'b0;
    wire FlushE = 1'b0;

    // Stage Wires
    // Fetch (IF) Stage
    wire [31:0] PCF, PCPlus4F;
    wire [ 2:0] funct3F = Instr[14:12];

    // Decode (ID) Stage
    wire [31:0] PCD, PCPlus4D, RD1D, RD2D, ImmExtD;
    wire [ 2:0] funct3D;

    // Execute (EX) Stage
    wire [31:0] RD1E, RD2E, ImmExtE, PCE, PCPlus4E, WriteDataE, InstrE, PCTargetE;
    wire [ 4:0] Rs1E, Rs2E, RdE;
    wire [ 3:0] ALUControlE;
    wire [ 2:0] funct3E;
    wire [ 1:0] ResultSrcE, ASrcE;
    wire        MemWriteE, RegWriteE, JumpE, BranchE, ALUSrcE, JalrE;
    wire [31:0] ALUResultE, JalrTargetE, lAuiPCE;
    wire        PCSrcE;

    // Memory (MEM) Stage
    wire [31:0] ALUResultM, PCPlus4M, WriteDataM, FormattedReadDataM;
    wire [ 4:0] RdM;
    wire [ 2:0] funct3M;
    wire [ 1:0] ResultSrcM;
    wire        RegWriteM;

    // Writeback (WB) Stage
    wire [31:0] ReadDataW, PCPlus4W;
    wire [ 4:0] RdW;
    wire [ 2:0] funct3W;
    wire [ 1:0] ResultSrcW;
    wire        RegWriteW;

    // Stage 1: Fetch
    stage_fetch fetch (
        .clk(clk), .reset(reset),
        .StallF(StallF),
        .JalrE(JalrE), .PCSrc(PCSrcE),
        .PCTarget(PCTargetE),      // Target address calculated in Decode
        .JalrTarget(JalrTargetE),  // Jalr target calculated in Execute
        .PC(PCF),
        .PCPlus4(PCPlus4F)
    );

    pipe_fd plfd (
        .clk(clk), .reset(reset),
        .StallD(StallD), .FlushD(FlushD),
        .funct3(funct3F),
        .PC(PCF), .PCPlus4(PCPlus4F), .Instr(Instr),
        .funct3D(funct3D), .PCD(PCD), .PCPlus4D(PCPlus4D), .InstrD(InstrD)
    );

    // Stage 2: Decode
    stage_decode decode (
        .clk(clk),
        .RegWriteW(RegWriteW),
        .RdW(RdW),
        .ImmSrc(ImmSrc),
        .PCD(PCD), .InstrD(InstrD), .ResultW(Result),
        .WriteData(RD2D), .RD1(RD1D), .ImmExt(ImmExtD)
    );

    pipe_de plde (
        .clk(clk), .reset(reset), .FlushE(FlushE),
        .WriteData(RD2D), .RD1(RD1D), .ImmExt(ImmExtD),
        .PCD(PCD), .PCPlus4D(PCPlus4D), .InstrD(InstrD),
        .ALUControl(ALUControl), .funct3D(funct3D),
        .ResultSrc(ResultSrc), .ASrc(ASrc),
        .RegWrite(RegWrite), .Jump(Jump), .Branch(Branch),
        .ALUSrc(ALUSrc), .Jalr(Jalr), .MemWrite(MemWrite),

        .RD1E(RD1E), .ImmExtE(ImmExtE), .PCE(PCE), .PCPlus4E(PCPlus4E),
        .WriteDataE(WriteDataE), .InstrE(InstrE),
        .Rs1E(Rs1E), .Rs2E(Rs2E), .RdE(RdE),
        .ALUControlE(ALUControlE), .funct3E(funct3E),
        .ResultSrcE(ResultSrcE), .ASrcE(ASrcE),
        .MemWriteE(MemWriteE), .RegWriteE(RegWriteE),
        .JumpE(JumpE), .BranchE(BranchE), .ALUSrcE(ALUSrcE), .JalrE(JalrE)
    );

    // Stage 3: Execute
    stage_execute execute (
        .RD1E(RD1E), .PCE(PCE), .WriteDataE(WriteDataE), .ImmExtE(ImmExtE),
        .InstrE(InstrE), .ALUControlE(ALUControlE), .funct3E(funct3E),
        .ASrcE(ASrcE), .ALUSrcE(ALUSrcE), .BranchE(BranchE), .JumpE(JumpE), .JalrE(JalrE),

        .lAuiPC(lAuiPCE),
        .ALUResult(ALUResultE),
        .JalrTarget(JalrTargetE),
        .PCSrc(PCSrcE),
        .PCTarget(PCTargetE)
    );

    pipe_em plem (
        .clk(clk), .reset(reset),
        .WriteDataE(WriteDataE), .ALUResult(ALUResultE), .PCPlus4E(PCPlus4E),
        .RdE(RdE), .funct3E(funct3E), .ResultSrcE(ResultSrcE),
        .RegWriteE(RegWriteE), .MemWriteE(MemWriteE),

        .ALUResultM(ALUResultM), .PCPlus4M(PCPlus4M), .WriteDataM(WriteDataM),
        .RdM(RdM), .funct3M(funct3M), .ResultSrcM(ResultSrcM),
        .RegWriteM(RegWriteM), .MemWriteM(MemWriteM)
    );

    // Stage 4: Memory
    stage_memory memory (
        .ALUResultM(ALUResultM), .ReadData(ReadData), .WriteDataM(WriteDataM), .funct3M(funct3M),
        .FormattedReadData(FormattedReadDataM),
        .Mem_WrData(Mem_WrData), .Mem_WrAddr(Mem_WrAddr)
    );

    pipe_mw plmw (
        .clk(clk), .reset(reset),
        .ALUResultM(ALUResultM), .FormattedReadData(FormattedReadDataM),
        .RdM(RdM), .PCPlus4M(PCPlus4M), .WriteDataM(WriteDataM), .funct3M(funct3M),
        .ResultSrcM(ResultSrcM), .RegWriteM(RegWriteM),

        .ALUResultW(ALUResultW), .ReadDataW(ReadDataW), .RdW(RdW),
        .PCPlus4W(PCPlus4W), .WriteDataW(WriteDataW), .funct3W(funct3W),
        .ResultSrcW(ResultSrcW), .RegWriteW(RegWriteW)
    );

    // Stage 5: Writeback
    mux4 #(32) resultmux (
        .d0(ALUResultW),
        .d1(ReadDataW),
        .d2(PCPlus4W),
        .d3(ALUResultW), // Note: Route LUI/AUIPC via ALUResult to avoid unpipelined lAuiPC
        .sel(ResultSrcW),
        .y(Result)
    );

    // Outputs
    assign PC = PCF;
    assign PCW = PCPlus4W;
    assign funct3 = funct3M;

endmodule
