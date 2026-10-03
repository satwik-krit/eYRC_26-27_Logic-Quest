
// alu.v - ALU module

module alu #(
    parameter WIDTH = 32
) (
    input      [WIDTH-1:0] a, b,  // operands
    input      [3:0]       alu_ctrl,  // ALU control
    output reg [WIDTH-1:0] alu_out,   // ALU output
    output                 zero       // zero flag
);

  always @(*) begin
    case (alu_ctrl)
      4'b0000:  alu_out = a + b;  // ADD
      4'b0001:  alu_out = a + ~b + 1;  // SUB
      4'b0010:  alu_out = a & b;  // AND
      4'b0011:  alu_out = a | b;  // OR
      4'b0101: begin  //SLT (Signed less than)
        // Since MSB is the sign bit we can simply check that 
        // rather than performing a complete comparison.
        if (a[31] != b[31]) alu_out = a[31] ? 1 : 0;
        else alu_out = (a < b) ? 1 : 0;
      end
      4'b0110:  alu_out = a << b[4:0];  // Shift Left
      4'b0111:  alu_out = (a < b) ? 1 : 0;  // Unsigned comparison
      4'b0100:  alu_out = a ^ b;
      4'b1000:  alu_out = a >> b[4:0]; // Shift Right
      4'b1001:  alu_out = $signed(a) >>> b[4:0]; // Shift Right Arithmetic (preserve sign bit)
      4'b1010:  alu_out = (a == b) ? 1 : 0; // beq
      4'b1011:  alu_out = (a != b) ? 1 : 0; // bne
      4'b1100:  alu_out = ($signed(a) < $signed(b)) ? 1 : 0; // blt (signed less than)
      4'b1101:  alu_out = ($signed(a) >= $signed(b)) ? 1 : 0; // bge (signed greater than or equal to)
      4'b1110:  alu_out = (a < b) ? 1 : 0; // bltu (unsigned less than)
      4'b1111:  alu_out = (a >= b) ? 1 : 0; // bgeu (unsigned greater than or equal to)
      default:  alu_out = 0;
    endcase
  end

  assign zero = alu_out[0];

endmodule

