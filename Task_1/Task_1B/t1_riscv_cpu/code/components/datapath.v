
// datapath.v
module datapath (
    input         clk, reset,
    input [1:0]   ResultSrc,
    input         PCSrc, ALUSrc,
    input         RegWrite,
    input [2:0]   ImmSrc,
    input [2:0]   ALUControl,
	 input [1:0] ASrc, 
	 input Jalr,
    output Zero,
    output [31:0] PC,
    input  [31:0] Instr,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] Result
);

wire [31:0] PCNext, PCPlus4, PCTarget;
wire [31:0] ImmExt, SrcA, SrcB, WriteData, ALUResult;
wire [31:0] RD1; 

// next PC logic
reset_ff #(32) pcreg(clk, reset, PCNext, PC);
adder          pcadd4(PC, 32'd4, PCPlus4);
adder          pcaddbranch(PC, ImmExt, PCTarget);
wire [31:0] PCBranchOrPlus4;
mux2 #(32)  pcmux(PCPlus4, PCTarget, PCSrc, PCBranchOrPlus4);
assign PCNext = Jalr ? {ALUResult[31:1], 1'b0} : PCBranchOrPlus4;
// register file logic
// SrcA output becomes RD1
reg_file   rf(clk, RegWrite, Instr[19:15], Instr[24:20], Instr[11:7], Result, RD1, WriteData);
imm_extend     ext (Instr[31:7], ImmSrc, ImmExt);

// ALU logic
mux2 #(32)     srcbmux(WriteData, ImmExt, ALUSrc, SrcB);
alu            alu (SrcA, SrcB, ALUControl, ALUResult, Zero);
mux3 #(32)     resultmux(ALUResult, ReadData, PCPlus4, ResultSrc, Result);
mux3 #(32) srcamux(RD1, PC, 32'b0, ASrc, SrcA); // ALU A-input mux: 00 = rs1, 01 = PC, 10 = zero because RD1, PC and 0 are the inputs
//Arsc is a selecter and srcA is the output 

assign Mem_WrData = WriteData;
assign Mem_WrAddr = ALUResult;

endmodule

