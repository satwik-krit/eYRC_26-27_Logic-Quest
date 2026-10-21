`default_nettype none
// datapath.v
module datapath (
    input         clk, reset,
    input  [1:0]  ResultSrc,
    input         ALUSrc, RegWrite,
    input  [2:0]  ImmSrc,
    input  [3:0]  ALUControl,
    input  [1:0]  ASrc,
    input         Branch, Jump, Jalr, MemWrite,
    input  [31:0] Instr,
    input  [31:0] ReadData,
    // output        Zero,
    output [31:0] PC,
    output [31:0] Mem_WrAddr, Mem_WrData,
    output [31:0] Result,
    output [31:0] PCW, ALUResultW, WriteDataW,
    output [31:0] InstrD
);

wire [31:0] PCNext, PCJalr, PCPlus4, PCTarget, AuiPC, lAuiPC;
wire [31:0] ImmExt, SrcA, SrcB, WriteData, ALUResult;
wire [31:0] RD1;
wire [ 2:0] funct3 = Instr[14:12];
wire TakeBranch, Zero;

reg [31:0] InstrD_reg, PCD, PCPlus4D;
reg [ 2:0] funct3D;

reg [31:0] RD1E, RD2E, ImmExtE, PCE, PCPlus4E, WriteDataE;
reg [ 4:0] Rs1E, Rs2E, RdE; // Source registers and destination register's address
reg [ 3:0] ALUControlE;
reg [ 2:0] funct3E;
reg [ 1:0] ResultSrcE, ASrcE;
reg        RegWriteE, JumpE, BranchE, MemWriteE, ALUSrcE, JalrE;

reg [31:0] ALUResultM, WriteDataM, PCPlus4M;
reg [ 4:0] RdM;
reg [ 1:0] ResultSrcM;
reg        RegWriteM, MemWriteM;
reg [ 2:0] funct3M;

reg [31:0] ALUResultW_reg, ReadDataW, PCPlus4W, WriteDataW_reg, ResultW;
reg [ 4:0] RdW;
reg [ 1:0] ResultSrcW;
reg        RegWriteW;
reg [ 2:0] funct3W;

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

wire PCSrc = ((BranchE & TakeBranch) || JumpE || JalrE) ? 1'b1 : 1'b0;

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
always @(posedge clk) begin
    InstrD_reg <= Instr;
    PCD        <= PC;
    PCPlus4D   <= PCPlus4;
    funct3D    <= funct3;
end


wire FlushD = 0; // remove it after adding hazard unit
// FlushD - should be wired from hazard unit
// pl_reg_fd plfd (clk, StallD, FlushD, Instr, PC, PCPlus4,
            //   InstrD, PCD, PCPlus4D);

adder          pcaddbranch(PCD, ImmExt, PCTarget);

// register file logic
reg_file       rf (clk, RegWriteW, InstrD[19:15], InstrD[24:20], InstrD[11:7], ResultW, RD1, WriteData);
imm_extend     ext (InstrD[31:7], ImmSrc, ImmExt);

// Pipeline Register 2 -> Decode | Execute
always @(posedge clk) begin
    RD1E <= RD1;
    RD2E <= Result;
    ImmExtE <= ImmExt;

    PCE <= PCD;
    PCPlus4E <= PCPlus4D;

    MemWriteE <=MemWrite;
    RegWriteE <= RegWrite;
    JumpE <= Jump;
    BranchE <= Branch;
    ResultSrcE <= ResultSrc;
    ASrcE <= ASrc;
    ALUSrcE <= ALUSrc;
    JalrE <= Jalr;
    ALUControlE <= ALUControl;
    WriteDataE <= WriteData;

    Rs1E <= InstrD[19:15];
    Rs2E <= InstrD[24:20];
    RdE  <= InstrD[11:7];

    funct3E <= funct3D;
end

// ALU logic
mux3 #(32)     srcamux (RD1E, PCE, 32'b0, ASrcE, SrcA);
mux2 #(32)     srcbmux (WriteDataE, ImmExtE, ALUSrcE, SrcB);

alu            alu (
                .a(SrcA),
                .b(SrcB),
                .alu_ctrl(ALUControlE),
                .alu_out(ALUResult),
                .zero(Zero)
            );

adder #(32)    auipcadder ({Instr[31:12], 12'b0}, PC, AuiPC);
mux2 #(32)     lauipcmux (AuiPC, {Instr[31:12], 12'b0}, Instr[5], lAuiPC);

// TODO: Investigate this.
branching_unit bu (funct3E, Zero, ALUResult[31], TakeBranch);

// Pipeline Register 3 -> Execute | Memory
always @(posedge clk) begin
    ALUResultM <= ALUResult;
    WriteDataM <= WriteDataE;
    PCPlus4M <= PCPlus4E;
    RdM <= RdE;
    ResultSrcM <= ResultSrcE;
    RegWriteM <= RegWriteE;
    MemWriteM <= MemWriteE;

    funct3M <= funct3E;
end

// assign MemWriteM = MemWriteM_reg;

// Pipeline Register 4 -> Memory | Writeback
always @(posedge clk) begin
    ALUResultW_reg <= ALUResultM;
    ReadDataW <= FormattedReadData;
    RdW <= RdM;
    PCPlus4W <= PCPlus4M;
    ResultSrcW <= ResultSrcM;
    RegWriteW <= RegWriteM;
    WriteDataW_reg <= WriteDataM;

    funct3W <= funct3M;
end

assign ALUResultW = ALUResultW_reg;
assign PCW = PCPlus4W;
assign WriteDataW = WriteDataW_reg;
assign InstrD = InstrD_reg;

mux4 #(32)     resultmux(ALUResultW, ReadDataW, PCPlus4W, lAuiPC, ResultSrcW, ResultW);

// hazard unit


// Align store data to correct byte/halfword on 32-bit bus
reg [31:0] WriteData_aligned;

always @(*) begin
    case (funct3M)
        3'b000:  WriteData_aligned = WriteDataM << (8 * ALUResultM[1:0]); // SB
        3'b001:  WriteData_aligned = ALUResultM[1] ? { WriteDataM[15:0], 16'b0 } : WriteDataM; // SH
        default: WriteData_aligned = WriteDataM; // SW
    endcase
end

assign Mem_WrData = WriteData_aligned;
assign Mem_WrAddr = ALUResultM;

endmodule
