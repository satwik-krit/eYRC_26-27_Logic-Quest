`default_nettype none

module stage_fetch (
    input wire clk, reset,
    input wire StallF,
    input wire JalrE,
    input wire PCSrc,
    input wire [31:0] PCTarget,
    input wire [31:0] JalrTarget,

    output wire [31:0] PC,
    output wire [31:0] PCPlus4
);

    wire [31:0] PCNext, PCJalr;

    // next PC logic
    mux2 #(32)     pcmux(PCPlus4, PCTarget, PCSrc, PCNext);

    mux2 #(32)     jalrmux (PCNext, JalrTarget, JalrE, PCJalr);

    reset_ff #(32) pcreg(
        .clk(clk),
        .rst(reset),
        .clr(StallF),
        .d(PCJalr),
        .q(PC)
    );

    adder          pcadd4(PC, 32'd4, PCPlus4);

endmodule
