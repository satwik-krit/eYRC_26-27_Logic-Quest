
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
    output wire [2:0]  funct3,
    output wire        MemWriteM
);

    // -------------------------------------------------
    // Hazard-unit control signals (internal)
    // -------------------------------------------------

    wire StallF, StallD, FlushD, FlushE;
    wire localUseHazard;
    wire [1:0] ForwardAE, ForwardBE;

    // -------------------------------------------------
    // Fetch stage
    // -------------------------------------------------

    wire [31:0] PCF, PCPlus4F;
    wire [2:0] funct3F;

    assign funct3F = Instr[14:12];

    // -------------------------------------------------
    // Decode stage
    // -------------------------------------------------

    wire [31:0] PCD, PCPlus4D;
    wire [31:0] RD1D, RD2D, ImmExtD;
    wire [2:0] funct3D;

    wire [4:0] Rs1D, Rs2D, RdD;

    assign Rs1D = InstrD[19:15];
    assign Rs2D = InstrD[24:20];
    assign RdD  = InstrD[11:7];

    // -------------------------------------------------
    // Execute stage
    // -------------------------------------------------

    wire [31:0] RD1E, WriteDataE, ImmExtE;
    wire [31:0] PCE, PCPlus4E, InstrE;
    wire [31:0] PCTargetE, ALUResultE, JalrTargetE, lAuiPCE;
    wire [31:0] WriteDataForwardedE;

    wire [4:0] Rs1E, Rs2E, RdE;

    wire [3:0] ALUControlE;
    wire [2:0] funct3E;
    wire [1:0] ResultSrcE, ASrcE;

    wire MemWriteE, RegWriteE;
    wire JumpE, BranchE, ALUSrcE, JalrE;
    wire PCSrcE;

    // -------------------------------------------------
    // Memory stage
    // -------------------------------------------------

    wire [31:0] ALUResultM, PCPlus4M, WriteDataM;
    wire [31:0] FormattedReadDataM, ResultM;

    wire [4:0] RdM;
    wire [2:0] funct3M;
    wire [1:0] ResultSrcM;
    wire RegWriteM;

    // -------------------------------------------------
    // Writeback stage
    // -------------------------------------------------

    wire [31:0] ReadDataW, PCPlus4W, ResultW;
    wire [4:0] RdW;
    wire [2:0] funct3W;
    wire [1:0] ResultSrcW;
    wire RegWriteW;
	 
	 

    // -------------------------------------------------
    // Hazard unit
    // -------------------------------------------------

    hazard_unit hazard (
        .Rs1D(Rs1D),
        .Rs2D(Rs2D),
        .Rs1E(Rs1E),
        .Rs2E(Rs2E),
        .RdE(RdE),
        .RdM(RdM),
        .RdW(RdW),

        .ResultSrcE(ResultSrcE),
        .RegWriteM(RegWriteM),
        .RegWriteW(RegWriteW),
        .PCSrcE(PCSrcE),

        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE),
        .StallF(StallF),
        .StallD(StallD),
        .FlushD(FlushD),
        .FlushE(FlushE),
        .localUseHazard(localUseHazard)
    );

    // -------------------------------------------------
    // Stage 1: Fetch
    // -------------------------------------------------

    stage_fetch fetch (
        .clk(clk),
        .reset(reset),
        .StallF(StallF),
        .JalrE(JalrE),
        .PCSrc(PCSrcE),
        .PCTarget(PCTargetE),
        .JalrTarget(JalrTargetE),
        .PC(PCF),
        .PCPlus4(PCPlus4F)
    );

    pipe_fd plfd (
        .clk(clk),
        .reset(reset),
        .StallD(StallD),
        .FlushD(FlushD),
        .funct3(funct3F),
        .PC(PCF),
        .PCPlus4(PCPlus4F),
        .Instr(Instr),
        .funct3D(funct3D),
        .PCD(PCD),
        .PCPlus4D(PCPlus4D),
        .InstrD(InstrD)
    );

    // -------------------------------------------------
    // Stage 2: Decode
    // -------------------------------------------------

    stage_decode decode (
        .clk(clk),
        .RegWriteW(RegWriteW),
        .RdW(RdW),
        .ImmSrc(ImmSrc),
        .PCD(PCD),
        .InstrD(InstrD),
        .ResultW(ResultW),
        .WriteData(RD2D),
        .RD1(RD1D),
        .ImmExt(ImmExtD)
    );

    // -------------------------------------------------
    // Decode-to-Execute pipeline register
    // -------------------------------------------------

    pipe_de plde (
        .clk(clk),
        .clr(reset | FlushE),
        .en(1'b1),

        .RD1D(RD1D),
        .RD2D(RD2D),
        .ImmExtD(ImmExtD),
        .PCD(PCD),
        .PCPlus4D(PCPlus4D),
        .InstrD(InstrD),

        .Rs1D(Rs1D),
        .Rs2D(Rs2D),
        .RdD(RdD),
        .funct3D(funct3D),

        .ALUControlD(ALUControl),
        .ResultSrcD(ResultSrc),
        .ASrcD(ASrc),
        .RegWriteD(RegWrite),
        .JumpD(Jump),
        .BranchD(Branch),
        .ALUSrcD(ALUSrc),
        .JalrD(Jalr),
        .MemWriteD(MemWrite),

        .RD1E(RD1E),
        .RD2E(WriteDataE),
        .ImmExtE(ImmExtE),
        .PCE(PCE),
        .PCPlus4E(PCPlus4E),
        .InstrE(InstrE),

        .Rs1E(Rs1E),
        .Rs2E(Rs2E),
        .RdE(RdE),
        .funct3E(funct3E),

        .ALUControlE(ALUControlE),
        .ResultSrcE(ResultSrcE),
        .ASrcE(ASrcE),
        .RegWriteE(RegWriteE),
        .JumpE(JumpE),
        .BranchE(BranchE),
        .ALUSrcE(ALUSrcE),
        .JalrE(JalrE),
        .MemWriteE(MemWriteE)
    );

    // -------------------------------------------------
    // Stage 3: Execute
    // -------------------------------------------------

    stage_execute execute (
        .RD1E(RD1E),
        .PCE(PCE),
        .WriteDataE(WriteDataE),
        .ImmExtE(ImmExtE),
        .InstrE(InstrE),
        .ALUControlE(ALUControlE),
        .funct3E(funct3E),
        .ASrcE(ASrcE),
        .ALUSrcE(ALUSrcE),
        .BranchE(BranchE),
        .JumpE(JumpE),
        .JalrE(JalrE),

        .forwardAE(ForwardAE),
        .forwardBE(ForwardBE),
        .ResultW(ResultW),
        .ResultM(ResultM),
        .WriteDataForwardedE(WriteDataForwardedE),

        .lAuiPC(lAuiPCE),
        .ALUResult(ALUResultE),
        .JalrTarget(JalrTargetE),
        .PCTarget(PCTargetE),
        .PCSrc(PCSrcE)
    );

    // -------------------------------------------------
    // Execute-to-Memory pipeline register
    // -------------------------------------------------

    pipe_em plem (
        .clk(clk),
        .reset(reset),
        .WriteDataE(WriteDataForwardedE),
        .ALUResult(ALUResultE),
        .PCPlus4E(PCPlus4E),
        .RdE(RdE),
        .funct3E(funct3E),
        .ResultSrcE(ResultSrcE),
        .RegWriteE(RegWriteE),
        .MemWriteE(MemWriteE),

        .ALUResultM(ALUResultM),
        .PCPlus4M(PCPlus4M),
        .WriteDataM(WriteDataM),
        .RdM(RdM),
        .funct3M(funct3M),
        .ResultSrcM(ResultSrcM),
        .RegWriteM(RegWriteM),
        .MemWriteM(MemWriteM)
    );

    // -------------------------------------------------
    // Stage 4: Memory
    // -------------------------------------------------

    stage_memory memory (
        .ALUResultM(ALUResultM),
        .ReadData(ReadData),
        .WriteDataM(WriteDataM),
        .funct3M(funct3M),
        .FormattedReadData(FormattedReadDataM),
        .Mem_WrData(Mem_WrData),
        .Mem_WrAddr(Mem_WrAddr)
    );

    pipe_mw plmw (
        .clk(clk),
        .reset(reset),
        .ALUResultM(ALUResultM),
        .FormattedReadData(FormattedReadDataM),
        .RdM(RdM),
        .PCPlus4M(PCPlus4M),
        .WriteDataM(WriteDataM),
        .funct3M(funct3M),
        .ResultSrcM(ResultSrcM),
        .RegWriteM(RegWriteM),

        .ALUResultW(ALUResultW),
        .ReadDataW(ReadDataW),
        .RdW(RdW),
        .PCPlus4W(PCPlus4W),
        .WriteDataW(WriteDataW),
        .funct3W(funct3W),
        .ResultSrcW(ResultSrcW),
        .RegWriteW(RegWriteW)
    );

    // -------------------------------------------------
    // Memory-stage result for forwarding
    // -------------------------------------------------

    mux4 #(32) resultmuxM (
        .d0(ALUResultM),
        .d1(FormattedReadDataM),
        .d2(PCPlus4M),
        .d3(ALUResultM),
        .sel(ResultSrcM),
        .y(ResultM)
    );

    // -------------------------------------------------
    // Stage 5: Writeback
    // -------------------------------------------------

    mux4 #(32) resultmux (
        .d0(ALUResultW),
        .d1(ReadDataW),
        .d2(PCPlus4W),
        .d3(ALUResultW),
        .sel(ResultSrcW),
        .y(ResultW)
    );

    // Preserve the original datapath interface.
    assign Result = ResultW;
    assign PC = PCF;
	 assign PCW = PCPlus4W - 32'd4;
    assign funct3 = funct3M;

endmodule

`default_nettype wire
