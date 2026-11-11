
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
	 
	 // Hazard-unit forwarding controls
    input wire [1:0] forwardAE,
    input wire [1:0] forwardBE,
	 
	 input wire [31:0] ResultW,
	 input wire [31:0] ResultM,

    output wire [31:0] lAuiPC,
    output wire [31:0] ALUResult,
    output wire [31:0] JalrTarget,
    output wire [31:0] PCTarget,
    output wire [31:0] WriteDataForwardedE,

	 
    output wire        PCSrc
);

    wire [31:0] SrcA, SrcB, AuiPC;
    // See where these two wires need to be connected.
    wire        TakeBranch;

    adder pcaddbranch (PCE, ImmExtE, PCTarget);
	
	
	wire [31:0] ForwardedA;
	wire [31:0] ForwardedB;

mux3 #(32) forwardAmux (
    RD1E, ResultW, ResultM, forwardAE, ForwardedA
);

mux3 #(32) forwardBmux (
    WriteDataE, ResultW, ResultM, forwardBE, ForwardedB
);

assign WriteDataForwardedE = ForwardedB;
	 
    mux3 #(32) srcamux (ForwardedA, PCE, 32'b0, ASrcE, SrcA);
    mux2 #(32) srcbmux (ForwardedB, ImmExtE, ALUSrcE, SrcB);

    alu alu (
        .a(SrcA),
        .b(SrcB),
        .alu_ctrl(ALUControlE),
        .alu_out(ALUResult),
        .zero(TakeBranch)
    );

    adder #(32) auipcadder (ImmExtE, PCE, AuiPC);
    mux2 #(32)  lauipcmux (AuiPC, ImmExtE, InstrE[5], lAuiPC);

    // // TODO: Investigate this.
//    branching_unit bu (
//        .funct3(funct3E),
//        .Zero(Zero),
//        .ALUR31(ALUResult[31]),
//        .Branch(TakeBranch)
//    );
//using the ALU's branching unit as more functions and stuff present there
 
	 assign PCSrc = (BranchE & TakeBranch) | JumpE | JalrE;
    assign JalrTarget = {ALUResult[31:1], 1'b0};

endmodule

`default_nettype wire
