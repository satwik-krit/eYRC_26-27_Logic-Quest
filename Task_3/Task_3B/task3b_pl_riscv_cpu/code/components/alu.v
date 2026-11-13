// alu.v - ALU module

`default_nettype none

module alu #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] a, b,       // operands
    input  wire [3:0]       alu_ctrl,   // ALU control
    output reg  [WIDTH-1:0] alu_out,    // ALU output
    output wire             zero        // branch/condition flag (alu_out[0])
);

    // is_sub = 1 for SUB (0001), SLT (0101), SLTU (0111), and branches (1010..1111)
    wire is_sub = (alu_ctrl == 4'b0001) || (alu_ctrl == 4'b0101) ||
                  (alu_ctrl == 4'b0111) || alu_ctrl[3];

    wire [WIDTH-1:0] b_inv   = is_sub ? ~b : b;
    wire [WIDTH:0]   sum_ext = {1'b0, a} + {1'b0, b_inv} + {{WIDTH{1'b0}}, is_sub};
    wire [WIDTH-1:0] sum     = sum_ext[WIDTH-1:0];
    wire             cout    = sum_ext[WIDTH];

    // Signed overflow: a and b have opposite signs, and result sign differs from a
    wire ovf = (a[WIDTH-1] ^ b[WIDTH-1]) & (a[WIDTH-1] ^ sum[WIDTH-1]);

    wire ltu = ~cout;                   // unsigned: a < b
    wire geu = cout;                    // unsigned: a >= b
    wire lts = sum[WIDTH-1] ^ ovf;      // signed:   a < b
    wire ges = ~lts;                    // signed:   a >= b

    // Reuse XOR result for equality checks
    wire [WIDTH-1:0] xor_res = a ^ b;
    wire             eq      = ~(|xor_res);

    function [WIDTH-1:0] bit_reverse;
        input [WIDTH-1:0] in;
        integer k;
        begin
            for (k = 0; k < WIDTH; k = k + 1)
                bit_reverse[k] = in[WIDTH - 1 - k];
        end
    endfunction

    wire is_sll = (alu_ctrl == 4'b0110);
    wire is_sra = (alu_ctrl == 4'b1001);

    wire [WIDTH-1:0] shift_in  = is_sll ? bit_reverse(a) : a;
    wire [WIDTH:0]   shift_ext = {(is_sra & shift_in[WIDTH-1]), shift_in};
    wire [WIDTH:0]   shift_raw = $signed(shift_ext) >>> b[4:0];
    wire [WIDTH-1:0] shift_res = is_sll ? bit_reverse(shift_raw[WIDTH-1:0]) : shift_raw[WIDTH-1:0];

    always @(*) begin
        case (alu_ctrl)
            4'b0000: alu_out = sum;                         // ADD
            4'b0001: alu_out = sum;                         // SUB
            4'b0010: alu_out = a & b;                       // AND
            4'b0011: alu_out = a | b;                       // OR
            4'b0100: alu_out = xor_res;                     // XOR
            4'b0101: alu_out = {{(WIDTH-1){1'b0}}, lts};    // SLT
            4'b0110: alu_out = shift_res;                   // SLL
            4'b0111: alu_out = {{(WIDTH-1){1'b0}}, ltu};    // SLTU
            4'b1000: alu_out = shift_res;                   // SRL
            4'b1001: alu_out = shift_res;                   // SRA
            4'b1010: alu_out = {{(WIDTH-1){1'b0}}, eq};     // BEQ
            4'b1011: alu_out = {{(WIDTH-1){1'b0}}, ~eq};    // BNE
            4'b1100: alu_out = {{(WIDTH-1){1'b0}}, lts};    // BLT
            4'b1101: alu_out = {{(WIDTH-1){1'b0}}, ges};    // BGE
            4'b1110: alu_out = {{(WIDTH-1){1'b0}}, ltu};    // BLTU
            4'b1111: alu_out = {{(WIDTH-1){1'b0}}, geu};    // BGEU
            default: alu_out = {WIDTH{1'b0}};
        endcase
    end

    assign zero = alu_out[0];

endmodule

`default_nettype wire
