
// reset_ff.v - 32-bit resettable D flip-flop

module reset_ff #(parameter WIDTH = 32) (
    input       clk, rst, clr,
    input       [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);

initial begin
    q = 0;
end

always @(posedge clk) begin
    if (rst) q <= 0; //q is the current value
    else if (!clr) q <= d;	//d is the next value to be stored in q
end

endmodule
