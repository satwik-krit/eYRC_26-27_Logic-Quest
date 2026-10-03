
// main_decoder.v - logic for main decoder

module main_decoder (
    input      [6:0] op,
    output reg [1:0] ResultSrc,
    output reg       MemWrite,
    output reg       Branch,
    output reg       ALUSrc,
    output reg       RegWrite,
    output reg       Jump,
    output reg [2:0] ImmSrc,
    output reg [1:0] ALUOp,
    output reg [1:0] ASrc,
    output reg       Jalr
);

  always @(*) begin
    case (op)
      7'b0000011: begin  // lw
        RegWrite = 1'b1;
        ImmSrc = 3'b000;
        ALUSrc = 1'b1;
        MemWrite = 1'b0;
        ResultSrc = 2'b01;
        Branch = 1'b0;
        ALUOp = 2'b00;
        Jump = 1'b0;
        ASrc = 2'b00;
        Jalr = 1'b0;
      end

      7'b0100011: begin  // sw
        RegWrite = 1'b0;
        ImmSrc = 3'b001;
        ALUSrc = 1'b1;
        MemWrite = 1'b1;
        ResultSrc = 2'b00;
        Branch = 1'b0;
        ALUOp = 2'b00;
        Jump = 1'b0;
        ASrc = 2'b00;
        Jalr = 1'b0;
      end

      7'b0110011: begin  // R-type (sltu)
        RegWrite = 1'b1;
        ImmSrc = 3'bxxx;
        ALUSrc = 1'b0;
        MemWrite = 1'b0;
        ResultSrc = 2'b00;
        Branch = 1'b0;
        ALUOp = 2'b10;
        Jump = 1'b0;
        ASrc = 2'b00;
        Jalr = 1'b0;
      end

      7'b1100011: begin  // beq
        RegWrite = 1'b0;
        ImmSrc = 3'b010;
        ALUSrc = 1'b0;
        MemWrite = 1'b0;
        ResultSrc = 2'b00;
        Branch = 1'b1;
        ALUOp = 2'b01;
        Jump = 1'b0;
        ASrc = 2'b00;
        Jalr = 1'b0;
      end

      7'b0010011: begin  // I-type ALu
        RegWrite = 1'b1;
        ImmSrc = 3'b000;
        ALUSrc = 1'b1;
        MemWrite = 1'b0;
        ResultSrc = 2'b00;
        Branch = 1'b0;
        ALUOp = 2'b10;
        Jump = 1'b0;
        ASrc = 2'b00;
        Jalr = 1'b0;
      end

      7'b1101111: begin  // jal
        RegWrite = 1'b1;
        ImmSrc = 3'b011;
        ALUSrc = 1'b0;
        MemWrite = 1'b0;
        ResultSrc = 2'b10;
        Branch = 1'b0;
        ALUOp = 2'b00;
        Jump = 1'b1;
        ASrc = 2'b00;
        Jalr = 1'b0;
      end

      7'b0110111: begin  // LUI
        RegWrite = 1'b1;
        ImmSrc = 3'b100;
        ALUSrc = 1'b1;
        MemWrite = 1'b0;
        ResultSrc = 2'b00;
        Branch = 1'b0;
        ALUOp = 2'b00;
        Jump = 1'b0;
        ASrc = 2'b10;
        Jalr = 1'b0;
      end

      7'b0010111: begin  // AUIPC (similar to LUi but immediate added to current PC address)
        RegWrite = 1'b1;
        ImmSrc = 3'b100;
        ALUSrc = 1'b1;
        MemWrite = 1'b0;
        ResultSrc = 2'b00;
        Branch = 1'b0;
        ALUOp = 2'b00;
        Jump = 1'b0;
        ASrc = 2'b01;
        Jalr = 1'b0;
      end

      7'b1100111: begin  // JALR
        RegWrite = 1'b1;
        ImmSrc = 3'b000;
        ALUSrc = 1'b1;
        MemWrite = 1'b0;
        ResultSrc = 2'b10;
        Branch = 1'b0;
        ALUOp = 2'b00;
        Jump = 1'b0;
        ASrc = 2'b00;
        Jalr = 1'b1;
      end

      default: begin
        RegWrite = 1'bx;
        ImmSrc = 3'bxxx;
        ALUSrc = 1'bx;
        MemWrite = 1'bx;
        ResultSrc = 2'bxx;
        Branch = 1'bx;
        ALUOp = 2'bxx;
        Jump = 1'bx;
        ASrc = 2'bxx;
        Jalr = 1'bx;
      end
    endcase
  end

endmodule

