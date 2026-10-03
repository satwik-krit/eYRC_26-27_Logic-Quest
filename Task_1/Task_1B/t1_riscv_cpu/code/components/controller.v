
// controller.v - controller for RISC-V CPU

module controller (
    input  [6:0] op,
    input  [2:0] funct3,
    input        funct7b5,
    input        Zero,
    output [1:0] ResultSrc,
    output       MemWrite,
    output       PCSrc,
    output       ALUSrc,
    output       RegWrite,
    output       Jump,
    output [2:0] ImmSrc,
    output [3:0] ALUControl,
    output [1:0] ASrc,
    output       Jalr
);

  wire [1:0] ALUOp;
  wire       Branch;

  main_decoder md (
      .op(op),
      .ResultSrc(ResultSrc),
      .MemWrite(MemWrite),
      .Branch(Branch),
      .ALUSrc(ALUSrc),
      .RegWrite(RegWrite),
      .Jump(Jump),
      .ImmSrc(ImmSrc),
      .ALUOp(ALUOp),
      .ASrc(ASrc),
      .Jalr(Jalr)
  );

  alu_decoder ad (
      .opb5(op[5]),
      .funct3(funct3),
      .funct7b5(funct7b5),
      .ALUOp(ALUOp),
      .ALUControl(ALUControl)
  );

  // for jump and branch
  assign PCSrc = (Branch & Zero) | Jump;

endmodule

