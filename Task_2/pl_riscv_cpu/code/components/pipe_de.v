`default_nettype none

module pipe_de (
    input wire clk,
    input wire en,
    input wire clr,

    // Data coming from Decode
    input wire [31:0] RD1D,
    input wire [31:0] RD2D,
    input wire [31:0] ImmExtD,
    input wire [31:0] PCD,
    input wire [31:0] PCPlus4D,
    input wire [31:0] InstrD,

    // Register identifiers
    input wire [4:0] Rs1D,
    input wire [4:0] Rs2D,
    input wire [4:0] RdD,
    input wire [2:0] funct3D,

    // Control signals generated in Decode
    input wire RegWriteD,
    input wire [1:0] ResultSrcD,
    input wire MemWriteD,
    input wire BranchD,
    input wire JumpD,
    input wire JalrD,
    input wire [3:0] ALUControlD,
    input wire ALUSrcD,
    input wire [1:0] ASrcD,

    // Data passed into Execute
    output reg [31:0] RD1E,
    output reg [31:0] RD2E,
    output reg [31:0] ImmExtE,
    output reg [31:0] PCE,
    output reg [31:0] PCPlus4E,
    output reg [31:0] InstrE,

    // Register identifiers passed into Execute
    output reg [4:0] Rs1E,
    output reg [4:0] Rs2E,
    output reg [4:0] RdE,
    output reg [2:0] funct3E,

    // Control signals passed into Execute
    output reg RegWriteE,
    output reg [1:0] ResultSrcE,
    output reg MemWriteE,
    output reg JumpE,
    output reg BranchE,
    output reg [3:0] ALUControlE,
    output reg ALUSrcE,
    output reg [1:0] ASrcE,
    output reg JalrE
);

always@(posedge clk)
	begin
		if(clr)
			begin
			// Flush: insert a bubble
        RD1E       <= 32'b0;
        RD2E       <= 32'b0;
        ImmExtE    <= 32'b0;
        PCE        <= 32'b0;
        PCPlus4E   <= 32'b0;

        Rs1E       <= 5'b0;
        Rs2E       <= 5'b0;
        RdE        <= 5'b0;
        funct3E    <= 3'b0;

        RegWriteE  <= 1'b0;
        ResultSrcE <= 2'b0;
        MemWriteE  <= 1'b0;
        JumpE      <= 1'b0;
        BranchE    <= 1'b0;
        ALUControlE <= 4'b0;
        ALUSrcE    <= 1'b0;
        ASrcE      <= 2'b0;
        JalrE      <= 1'b0;
		  InstrE <= 32'h00000013;
		  end
			//clr takes priority over en
		else if(en) 
			begin
				RD1E       <= RD1D;
				RD2E       <= RD2D;
				ImmExtE    <= ImmExtD;
				PCE        <= PCD;
				PCPlus4E   <= PCPlus4D;

				Rs1E       <= Rs1D;
				Rs2E       <= Rs2D;
				RdE        <= RdD;
				funct3E    <= funct3D;

				RegWriteE  <= RegWriteD;
				ResultSrcE <= ResultSrcD;
				MemWriteE  <= MemWriteD;
				JumpE      <= JumpD;
				BranchE    <= BranchD;
				ALUControlE <= ALUControlD;
				ALUSrcE    <= ALUSrcD;
				ASrcE      <= ASrcD;
				JalrE      <= JalrD;
				InstrE <= InstrD;
			end

			
		end
	
		
endmodule
	
`default_nettype wire
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	