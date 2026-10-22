`default_nettype none

module pipe_fd (
    input wire clk, reset, StallD, FlushD,
    input wire [ 2:0] funct3,
    input wire [31:0] PC,
    input wire [31:0] PCPlus4,
    input wire [31:0] Instr,

    output reg [ 2:0] funct3D,
    output reg [31:0] PCD,
    output reg [31:0] PCPlus4D,
    output reg [31:0] InstrD
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            InstrD   <= 32'h00000013; // Inject NOP (addi x0, x0, 0)
            PCD      <= 32'b0;
            PCPlus4D <= 32'b0;
            funct3D  <= 3'b0;
        end else if (FlushD) begin
            InstrD   <= 32'h00000013; // Inject NOP (addi x0, x0, 0)
            PCD      <= 32'b0;
            PCPlus4D <= 32'b0;
            funct3D  <= 3'b0;
        end else if (!StallD) begin
            InstrD <= Instr;
            PCD        <= PC;
            PCPlus4D   <= PCPlus4;
            funct3D    <= funct3;
        end
    end

endmodule
