`default_nettype none

module pipe_fd (
    input wire clk,
    input wire reset,
    input wire StallD,
    input wire FlushD,

    input wire [2:0] funct3,
    input wire [31:0] PC,
    input wire [31:0] PCPlus4,
    input wire [31:0] Instr,

    output reg [2:0] funct3D,
    output reg [31:0] PCD,
    output reg [31:0] PCPlus4D,
    output reg [31:0] InstrD
);

    // flush_reg injects a NOP for one cycle when
    // reset or flush.
    reg flush_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // InstrD   <= 32'h00000013;
            PCD       <= 32'b0;
            PCPlus4D  <= 32'b0;
            flush_reg <= 1'b1;
        end
        else if (FlushD) begin
            // Discard the instruction on the wrong path.
            // InstrD   <= 32'h00000013;
            PCD       <= 32'b0;
            PCPlus4D  <= 32'b0;
            flush_reg <= 1'b1;
        end
        else if (!StallD) begin
            // Accept the new fetched instruction.
            // InstrD   <= Instr;
            PCD       <= PC;
            PCPlus4D  <= PCPlus4;
            flush_reg <= 1'b0;
        end
        // Otherwise, hold the existing Decode instruction.
    end

    // Directly pass this since we reg this for a cycle in instr_mem
    always @(*) begin
        InstrD  = flush_reg ? 32'h00000013 : Instr;
        funct3D = flush_reg ? 3'b0         : funct3;
    end

endmodule

`default_nettype wire
