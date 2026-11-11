`default_nettype none

module stage_decode (
    input wire clk,
    input wire RegWriteW,
    input wire [ 2:0] ImmSrc,
    input wire [31:0] PCD,
    input wire [31:0] InstrD,
    input wire [31:0] ResultW,
    input wire [ 4:0] RdW,

    output wire [31:0] WriteData,
    output wire [31:0] RD1,
    output wire [31:0] ImmExt
);

    // register file logic
    reg_file rf (
        .clk(clk),
        .wr_en(RegWriteW),
        .rd_addr1(InstrD[19:15]),
        .rd_addr2(InstrD[24:20]),
        .wr_addr(RdW),
        .wr_data(ResultW),
        .rd_data1(RD1),
        .rd_data2(WriteData)
    );

    imm_extend ext (InstrD[31:7], ImmSrc, ImmExt);

endmodule
