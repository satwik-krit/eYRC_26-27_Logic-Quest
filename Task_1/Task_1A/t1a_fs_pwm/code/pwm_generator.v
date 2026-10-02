// Logic Quest Bot : Task 1A : PWM Generator
/*
Instructions
-------------------
Students are not allowed to make any changes in the Module declaration.
This file is used to design a module which will scale down the clk_5MHz Clock Frequency to 500Hz and perform Pulse Width Modulation on it.

Recommended Quartus Version : 20.1
The submitted project file must be 20.1 compatible as the evaluation will be done on Quartus Prime Lite 20.1.

Warning: The error due to compatibility will not be entertained.
-------------------
*/

//PWM Generator
//Inputs : clk_5MHz, pulse_width
//Output : clk_500Hz, pwm_signal

module pwm_generator(
    input clk_5MHz,
    input reset_n,
    input [4:0] pulse_width,
    output reg clk_500Hz, pwm_signal
);

//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE //////////////////

localparam FREQ_IN      = 5_000_000;
localparam FREQ_OUT     = 500;
localparam MAX_STEPS    = 20;

localparam TOTAL_CYCLES = FREQ_IN / FREQ_OUT;
localparam STEP_SIZE    = TOTAL_CYCLES / MAX_STEPS;
localparam COUNTER_WIDTH = $clog2(TOTAL_CYCLES);

// 50% duty cycles in we are generating a 500Hz signal from 10,000 clock cycles.
localparam DUTY_CYCLE = TOTAL_CYCLES / 2;

reg [COUNTER_WIDTH-1:0] count;
//reg [4:0] pulse_width_latched;

always @(posedge clk_5MHz or negedge reset_n)
begin
   if (!reset_n) begin
      count <= 0;
      clk_500Hz <= 1'b0;
      pwm_signal <= 1'b0;
//      pulse_width_latched <= pulse_width;
   end
   
   else begin
      if (count == TOTAL_CYCLES - 1) begin 
        count <= 0;
//        pulse_width_latched <= pulse_width;
      end
      else begin
        count <= count + 1'b1;
//        pulse_width_latched <= pulse_width;
      end

      clk_500Hz <= (count < DUTY_CYCLE);

      pwm_signal <= (count < (pulse_width * STEP_SIZE));
      
    end
end
 
//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE//////////////////

endmodule