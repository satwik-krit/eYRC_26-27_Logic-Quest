//
//
//
//module pl_reg_fd 
//(	
//	input clk, en, clr,
//	input [31:0] InstrF, PCF, PCPlus4F,
//	output [31:0] InstrD, PCD, PCPlus4D
//);	
//
//initial begin
//	InstrD = 32'h00000013; //default value for storing the addition function and doesn't change anything architecturally during flush
//	PCD = 32'b0;	//standard riscV encoding 
//	PCPlus4D= 32'b0;
//	end
//
//always@(posedge clk)
//	begin
//		if(clr) //decoded registers are set to initial state
//			begin
//				InstrD <= 32'h00000013; 
//				PCD <= 32'b0;
//				PCPlus4D<= 32'b0;
//			end
//		else if(en) //normal operations when enabled
//			begin
//				InstrD <= InstrF;
//				PCD <= PCF;
//				PCPlus4D <= PCPlus4F; 
//			end
//	end
//
//endmodule
//			
		
