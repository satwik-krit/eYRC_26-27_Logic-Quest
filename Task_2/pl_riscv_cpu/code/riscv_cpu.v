
// riscv_cpu.v - single-cycle RISC-V CPU Processor

module riscv_cpu (
    input         clk, reset,
    output [31:0] PC,
    input  [31:0] Instr,
    output        MemWrite,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] Result,
    output [ 2:0] funct3,
    output [31:0] PCW, ALUResultW, WriteDataW
);

wire       ALUSrc, RegWrite, Branch, Jump, Jalr, MemWrite_controller;
wire [1:0] ResultSrc, ASrc;
wire [2:0] ImmSrc;
wire [3:0] ALUControl;
wire [31:0] InstrD;

controller  c   (
    .op(InstrD[6:0]),
    .funct3(InstrD[14:12]),
    .funct7b5(InstrD[30]),
    .ResultSrc(ResultSrc),
    .MemWrite(MemWrite_controller),
    .ALUSrc(ALUSrc),
    .ASrc(ASrc),
    .RegWrite(RegWrite),
    .Branch(Branch),
    .Jump(Jump),
    .Jalr(Jalr),
    .ImmSrc(ImmSrc),
    .ALUControl(ALUControl)
    // .Zero(Zero)
);

datapath    dp  (
    .clk(clk),
    .reset(reset),
    .ResultSrc(ResultSrc),
    .ALUSrc(ALUSrc),
    .ASrc(ASrc),
    .RegWrite(RegWrite),
    .ImmSrc(ImmSrc),
    .ALUControl(ALUControl),
    .Branch(Branch),
    .Jump(Jump),
    .Jalr(Jalr),
    .PC(PC),
    .Instr(Instr),
    .Mem_WrAddr(Mem_WrAddr),
    .Mem_WrData(Mem_WrData),
    .ReadData(ReadData),
    .Result(Result),
    .PCW(PCW),
    .MemWrite(MemWrite_controller),
    .MemWriteM(MemWrite),
    .funct3(funct3),
    .ALUResultW(ALUResultW),
    .WriteDataW(WriteDataW),
    .InstrD(InstrD)
    // .Zero(Zero)
);

endmodule
