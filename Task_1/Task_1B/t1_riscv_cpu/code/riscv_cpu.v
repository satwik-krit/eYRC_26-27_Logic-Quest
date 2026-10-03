// riscv_cpu.v - single-cycle RISC-V CPU Processor

module riscv_cpu (
    input         clk, reset,
    output [31:0] PC,
    input  [31:0] Instr,
    output        MemWrite,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] Result
);

wire        ALUSrc, RegWrite, Jump, Zero, PCSrc, Jalr;
wire [1:0]  ResultSrc, ASrc;
wire [3:0]  ImmSrc, ALUControl;

controller c   ( 
    .op(Instr[6:0]), 
    .funct3(Instr[14:12]), 
    .funct7b5(Instr[30]), 
    .Zero(Zero),
    .ResultSrc(ResultSrc),
    .MemWrite(MemWrite), 
    .PCSrc(PCSrc), 
    .ALUSrc(ALUSrc), 
    .RegWrite(RegWrite),
    .Jump(Jump),
    .ImmSrc(ImmSrc),
    .ALUControl(ALUControl),
    .ASrc(ASrc), 
    .Jalr(Jalr)
);

datapath dp  (
    .clk(clk),
    .reset(reset),
    .ResultSrc(ResultSrc),
    .PCSrc(PCSrc),
    .ALUSrc(ALUSrc),
    .RegWrite(RegWrite),
    .ImmSrc(ImmSrc),
    .ALUControl(ALUControl),
    .ASrc(ASrc),
    .Jalr(Jalr),
    .Zero(Zero),
    .PC(PC),
    .Instr(Instr),
    .Mem_WrAddr(Mem_WrAddr),
    .Mem_WrData(Mem_WrData),
    .ReadData(ReadData),
    .Result(Result)
);

endmodule