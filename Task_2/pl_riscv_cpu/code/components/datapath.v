// datapath.v
module datapath (
    input         clk, reset,
    input  [1:0]  ResultSrc,
    input         ALUSrc, RegWrite,
    input  [2:0]  ImmSrc,
    input  [3:0]  ALUControl,
    input  [1:0]  ASrc,
    input         Branch, Jump, Jalr,
    input  [31:0] Instr,
    input  [31:0] ReadData,
    // output        Zero,
    output [31:0] PC,
    output [31:0] Mem_WrAddr, Mem_WrData,
    output [31:0] Result,
    output [31:0] PCW, ALUResultW, WriteDataW
);

wire [31:0] PCNext, PCJalr, PCPlus4, PCTarget, AuiPC, lAuiPC;
wire [31:0] ImmExt, SrcA, SrcB, WriteData, ALUResult;
wire [31:0] RD1;
wire [2:0] funct3 = Instr[14:12];
wire TakeBranch, Zero;

// --- Custom Memory Read Formatting ---
reg [31:0] FormattedReadData;

reg [7:0] selected_byte;

always @(*) begin
    // ALUResult[1:0] tells us how to compute the address
    // of the byte to be selected.
    case (ALUResult[1:0])
        2'b00: selected_byte = ReadData[7:0];
        2'b01: selected_byte = ReadData[15:8];
        2'b10: selected_byte = ReadData[23:16];
        2'b11: selected_byte = ReadData[31:24];
        default: selected_byte = 8'b0;
    endcase
end

wire [15:0] selected_halfword = ALUResult[1] ? ReadData[31:16] : ReadData[15:0];

always @(*) begin
    case (funct3) // funct3
        3'b000:  FormattedReadData = { {24{selected_byte[7]}}, selected_byte }; // LB
        3'b001:  FormattedReadData = { {16{selected_halfword[15]}}, selected_halfword }; // LH
        3'b010:  FormattedReadData = ReadData; // LW
        3'b100:  FormattedReadData = { 24'b0, selected_byte }; // LBU
        3'b101:  FormattedReadData = { 16'b0, selected_halfword }; // LHU
        default: FormattedReadData = ReadData; // LW
    endcase
end
// -------------------------------------

wire PCSrc = ((Branch & TakeBranch) || Jump || Jalr) ? 1'b1 : 1'b0;

// next PC logic
mux2 #(32)     pcmux(PCPlus4, PCTarget, PCSrc, PCNext);

// Jalr targets must have the LSB set to 0
wire [31:0] JalrTarget = {ALUResult[31:1], 1'b0};
mux2 #(32)     jalrmux (PCNext, JalrTarget, Jalr, PCJalr);

// stallF - should be wired from hazard unit
wire StallF = 0; // remove it after adding hazard unit.
reset_ff #(32) pcreg(clk, reset, StallF, PCJalr, PC);
adder          pcadd4(PC, 32'd4, PCPlus4);

// Pipeline Register 1 -> Fetch | Decode

wire FlushD = 0; // remove it after adding hazard unit
// FlushD - should be wired from hazard unit
// pl_reg_fd plfd (clk, StallD, FlushD, Instr, PC, PCPlus4,
            //   InstrD, PCD, PCPlus4D);

adder          pcaddbranch(PC, ImmExt, PCTarget);

// register file logic
reg_file       rf (clk, RegWrite, Instr[19:15], Instr[24:20], Instr[11:7], Result, RD1, WriteData);
imm_extend     ext (Instr[31:7], ImmSrc, ImmExt);

// Pipeline Register 2 -> Decode | Execute

// ALU logic
mux3 #(32)     srcamux (RD1, PC, 32'b0, ASrc, SrcA);
mux2 #(32)     srcbmux (WriteData, ImmExt, ALUSrc, SrcB);

alu            alu (
                .a(SrcA),
                .b(SrcB),
                .alu_ctrl(ALUControl),
                .alu_out(ALUResult),
                .zero(Zero)
            );

adder #(32)    auipcadder ({Instr[31:12], 12'b0}, PC, AuiPC);
mux2 #(32)     lauipcmux (AuiPC, {Instr[31:12], 12'b0}, Instr[5], lAuiPC);

branching_unit bu (funct3, Zero, ALUResult[31], TakeBranch);

// Pipeline Register 3 -> Execute | Memory

// Pipeline Register 4 -> Memory | Writeback

mux4 #(32)     resultmux(ALUResult, FormattedReadData, PCPlus4, lAuiPC, ResultSrc, Result);

// hazard unit


// Align store data to correct byte/halfword on 32-bit bus
reg [31:0] WriteData_aligned;

always @(*) begin
    case (funct3)
        3'b000:  WriteData_aligned = WriteData << (8 * ALUResult[1:0]); // SB
        3'b001:  WriteData_aligned = ALUResult[1] ? { WriteData[15:0], 16'b0 } : WriteData; // SH
        default: WriteData_aligned = WriteData; // SW
    endcase
end

assign Mem_WrData = WriteData_aligned;
assign Mem_WrAddr = ALUResult;

// eventually these statements will be removed while adding pipeline registers
assign PCW = PC;
assign ALUResultW = ALUResult;
assign WriteDataW = WriteData;

endmodule
