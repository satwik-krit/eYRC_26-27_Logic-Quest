`default_nettype none

module stage_memory (
    input wire [31:0] ALUResultM,
    input wire [31:0] ReadData,
    input wire [31:0] WriteDataM,
    input wire [ 2:0] funct3M,

    output wire [31:0] FormattedReadData,
    output wire [31:0] Mem_WrData,
    output wire [31:0] Mem_WrAddr
);
    // We don't format any of the read or write data since data_mem already does that.
    assign FormattedReadData = ReadData;

    assign Mem_WrData = WriteDataM;
    assign Mem_WrAddr = ALUResultM;

endmodule

`default_nettype wire
