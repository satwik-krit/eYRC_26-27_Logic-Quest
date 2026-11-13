
// pl_riscv_cpu.v - Top Module to test riscv_cpu

module pl_riscv_cpu (
    input         clk, reset,
    input         Ext_MemWrite,
    input  [31:0] Ext_WriteData, Ext_DataAdr,
    output        MemWrite,
    output [31:0] WriteData, DataAdr, ReadData,
    output [31:0] PCW, Result, ALUResultW, WriteDataW
);

wire [31:0] Instr, PC;
wire [31:0] DataAdr_rv32, WriteData_rv32;
wire [ 2:0] Store, funct3;
wire        MemWrite_rv32;

// instantiate processor and memories
riscv_cpu rvcpu (
    .clk        (clk),
    .reset      (reset),
    .PC         (PC),
    .Instr      (Instr),
    .MemWrite   (MemWrite_rv32),
    .StallF     (StallF),
    .Mem_WrAddr (DataAdr_rv32),
    .Mem_WrData (WriteData_rv32),
    .ReadData   (ReadData),
    .Result     (Result),
    .funct3     (funct3),
    .PCW        (PCW),
    .ALUResultW (ALUResultW),
    .WriteDataW (WriteDataW)
);

instr_mem instrmem (
    .clk        (clk),
    .en         (~StallF),
    .instr_addr (PC),
    .instr      (Instr)
);

data_mem datamem (
    .clk         (clk),
    .wr_en       (MemWrite),
    .funct3      (Store),
    .wr_addr     (DataAdr),
    .wr_data     (WriteData),
    .rd_data_mem (ReadData)
);

assign Store = (Ext_MemWrite && reset) ? 3'b010 : funct3;
assign MemWrite  = (Ext_MemWrite && reset) ? 1'b1 : MemWrite_rv32;
assign WriteData = (Ext_MemWrite && reset) ? Ext_WriteData : WriteData_rv32;
assign DataAdr   = reset ? Ext_DataAdr : DataAdr_rv32;

endmodule
