// Logic Quest Bot : Task 1A : Frequency Scaling
/*
Instructions
-------------------
Students are not allowed to make any changes in the Module declaration.
This file is used to design a module which will scale down the 50MHz Clock Frequency to clk_5MHz

Recommended Quartus Version : 20.1
The submitted project file must be 20.1 compatible as the evaluation will be done on Quartus Prime Lite 20.1.

Warning: The error due to compatibility will not be entertained.
-------------------
*/

//Frequency Scaling
//Inputs : clk_50MHz
//Output : 5MHz


module frequency_scaling (
    input clk_50MHz,
    input reset_n,
    output reg clk_5MHz
);

//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE //////////////////

localparam FREQ_IN  = 50_000_000;
localparam FREQ_OUT = 5_000_000;

// -1 to account since count = 0 also counts a cycle
localparam TOTAL_CYCLES = FREQ_IN / FREQ_OUT;

localparam COUNTER_WIDTH = $clog2(TOTAL_CYCLES + 1);

reg [COUNTER_WIDTH-1:0] count;

always @(posedge clk_50MHz or negedge reset_n)
begin
   if (!reset_n) begin
      count <= 0;
      clk_5MHz <= 1'b0;
   end
   
   else begin
      if (count == TOTAL_CYCLES - 1) count <= 0;
      else count <= count + 1'b1;

      clk_5MHz <= (count < (TOTAL_CYCLES / 2));
   end
end
//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE //////////////////

endmodule

