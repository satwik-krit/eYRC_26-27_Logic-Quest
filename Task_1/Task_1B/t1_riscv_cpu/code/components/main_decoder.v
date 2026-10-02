
// main_decoder.v - logic for main decoder

module main_decoder (
    input  [6:0] op,
    output [1:0] ResultSrc,
    output       MemWrite, Branch, ALUSrc,
    output       RegWrite, Jump,
    output [2:0] ImmSrc,
    output [1:0] ALUOp,
	 output [1:0] ASrc,
	 output Jalr
);

reg [14:0] controls;

always @(*) begin
    case (op)
        // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump
        7'b0000011:begin
            controls = 15'b1_000_1_0_01_0_00_0_00_0; // lw //the I-type stuff
        end

        7'b0100011:begin
            controls = 15'b0_001_1_1_00_0_00_0_00_0; // sw //the s-type
        end

        7'b0110011:begin
            controls = 15'b1_xxx_0_0_00_0_10_0_00_0; // R–type
        end

        7'b1100011:begin
            controls = 15'b0_010_0_0_00_1_01_0_00_0; // beq //the b-type
        end

        7'b0010011:begin
            controls = 15'b1_000_1_0_00_0_10_0_00_0; // I–type ALU
        end

        7'b1101111:begin
            controls = 15'b1_011_0_0_10_0_00_1_00_0; // jal //the j-type
        end

		  7'b0110111:begin
            controls = 15'b1_100_1_0_00_0_00_0_10_0; // LUI  
        end

		  7'b0010111:begin
            controls = 15'b1_100_1_0_00_0_00_0_01_0; //similar to LUI but immediate is added to current PC address
        end

		  7'b1100111:begin
            controls = 15'b1_000_1_0_10_0_00_0_00_1; // jalr jumping to a relative address 
        end

        default: begin
            controls = 15'bx_xxx_x_x_xx_x_xx_x_xx_x; // ???
        end
end

assign {RegWrite, ImmSrc, ALUSrc, MemWrite, ResultSrc, Branch, ALUOp, Jump, ASrc, Jalr} = controls;

endmodule

