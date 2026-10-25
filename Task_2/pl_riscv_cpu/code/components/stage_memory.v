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

    // LOAD DATA FORMATTING (Memory -> Register File)
    reg [31:0] formatted_read;

    reg [7:0] selected_byte;

    always @(*) begin
        // ALUResultM[1:0] tells us how to compute the address
        // of the byte to be selected.
        case (ALUResultM[1:0])
        2'b00: selected_byte = ReadData[7:0];
        2'b01: selected_byte = ReadData[15:8];
        2'b10: selected_byte = ReadData[23:16];
        2'b11: selected_byte = ReadData[31:24];
        default: selected_byte = 8'b0;
        endcase
    end

    wire [15:0] selected_halfword = ALUResultM[1] ? ReadData[31:16] : ReadData[15:0];

    always @(*) begin
        case (funct3M)
        3'b000:  formatted_read = { {24{selected_byte[7]}}, selected_byte }; // LB
        3'b001:  formatted_read = { {16{selected_halfword[15]}}, selected_halfword }; // LH
        3'b010:  formatted_read = ReadData; // LW
        3'b100:  formatted_read = { 24'b0, selected_byte }; // LBU
        3'b101:  formatted_read = { 16'b0, selected_halfword }; // LHU
        default: formatted_read = ReadData; // LW
        endcase
    end

    // The data_mem module already formats this so we can skip it for now.
    // TODO: Trim out extra hardware that does this here.
    assign FormattedReadData = ReadData;


    // STORE DATA ALIGNMENT (Register file -> Memory)
    // Align store data to correct byte/halfword on 32-bit bus
    reg [31:0] WriteData_aligned;

    always @(*) begin
        case (funct3M)
            3'b000:  WriteData_aligned = WriteDataM << (8 * ALUResultM[1:0]); // SB
            3'b001:  WriteData_aligned = ALUResultM[1] ? { WriteDataM[15:0], 16'b0 } : WriteDataM; // SH
            default: WriteData_aligned = WriteDataM; // SW
        endcase
    end

    // The data_mem module already formats this so we can skip it for now.
    // TODO: Trim out extra hardware that does this here.
    assign Mem_WrData = WriteDataM;
    assign Mem_WrAddr = ALUResultM;

endmodule

`default_nettype wire