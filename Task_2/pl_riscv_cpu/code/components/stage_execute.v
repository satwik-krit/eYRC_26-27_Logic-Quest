`default_nettype none

module stage_execute (
    input wire [31:0] RD1E,
    input wire [31:0] PCE,
    input wire [31:0] WriteDataE,
    input wire [31:0] ImmExtE,
    // TODO: Reduce using 32 flip flop for accessing a single bit of the
    // instruction.
    input wire [31:0] InstrE,
    input wire [ 3:0] ALUControlE,
    input wire [ 2:0] funct3E,
    input wire [ 1:0] ASrcE,
    input wire        ALUSrcE,
    input wire        BranchE,
    input wire        JumpE,
    input wire        JalrE,

    output wire [31:0] lAuiPC,
    output wire [31:0] ALUResult,
    output wire [31:0] JalrTarget,
    output wire [31:0] PCTarget,
    output wire        PCSrc
);

    wire [31:0] SrcA, SrcB, AuiPC;
    // See where these two wires need to be connected.
    wire        Zero, TakeBranch;

    adder pcaddbranch (PCE, ImmExtE, PCTarget);

    mux3 #(32) srcamux (RD1E, PCE, 32'b0, ASrcE, SrcA);
    mux2 #(32) srcbmux (WriteDataE, ImmExtE, ALUSrcE, SrcB);

    alu alu (
        .a(SrcA),
        .b(SrcB),
        .alu_ctrl(ALUControlE),
        .alu_out(ALUResult),
        .zero(Zero)
    );

    adder #(32) auipcadder (ImmExtE, PCE, AuiPC);
    mux2 #(32)  lauipcmux (AuiPC, ImmExtE, InstrE[5], lAuiPC);

    // // TODO: Investigate this.
    branching_unit bu (
        .funct3(funct3E),
        .Zero(Zero),
        .ALUR31(ALUResult[31]),
        .Branch(TakeBranch)
    );

    assign PCSrc = ((BranchE & Zero) || JumpE || JalrE) ? 1'b1 : 1'b0;
    assign JalrTarget = {ALUResult[31:1], 1'b0};

endmodule
