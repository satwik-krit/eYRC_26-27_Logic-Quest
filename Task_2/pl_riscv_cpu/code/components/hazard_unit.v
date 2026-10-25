`default_nettype none

module hazard_unit (
    // Register indices in Decode
    input wire [4:0] Rs1D,
    input wire [4:0] Rs2D,

    // Register indices in Execute
    input wire [4:0] Rs1E,
    input wire [4:0] Rs2E,

    // Destination register indices
    input wire [4:0] RdE,
    input wire [4:0] RdM,
    input wire [4:0] RdW,

    // Control information
    input wire [1:0] ResultSrcE,
    input wire RegWriteM,
    input wire RegWriteW,
    input wire PCSrcE,

    // Forwarding controls
    output reg [1:0] ForwardAE,
    output reg [1:0] ForwardBE,

    // Stall/flush controls
    output wire StallF,
    output wire StallD,
    output wire FlushD,
    output wire FlushE,
    output wire localUseHazard
);

    // Operand A: prefer the newer result from Memory.
    always @(*) begin
        ForwardAE = 2'b00;

        if (RegWriteM &&
            (RdM != 5'd0) &&
            (RdM == Rs1E)) begin
            ForwardAE = 2'b10;
        end
        else if (RegWriteW &&
                 (RdW != 5'd0) &&
                 (RdW == Rs1E)) begin
            ForwardAE = 2'b01;
        end
    end

    // Operand B: same logic, using Rs2E.
    always @(*) begin
        ForwardBE = 2'b00;

        if (RegWriteM &&
            (RdM != 5'd0) &&
            (RdM == Rs2E)) begin
            ForwardBE = 2'b10;
        end
        else if (RegWriteW &&
                 (RdW != 5'd0) &&
                 (RdW == Rs2E)) begin
            ForwardBE = 2'b01;
        end
    end

    // Assumes ResultSrcE == 2'b01 uniquely identifies loads.
		//a stall isn't necessary for instructions which use the weight which is to be produced by the ALu in the younger instruction
	 //but a younger instruction with load takes an extra cycle tahts why stall and use the loadhazard
assign localUseHazard =
    (ResultSrcE == 2'b01) &&
    (RdE != 5'd0) &&
    ((RdE == Rs1D) || (RdE == Rs2D));

assign StallF = localUseHazard;
assign StallD = localUseHazard;

assign FlushD = PCSrcE;
assign FlushE = localUseHazard | PCSrcE;

endmodule

`default_nettype wire