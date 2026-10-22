// tb_check.v - self-checking testbench for stage4_test.hex
// Put it next to your sources and compile it with pl_riscv_cpu.v etc.
// Set TRACE to 1 to print one line per cycle (PC, instruction in Decode, write-back).
`timescale 1ns/1ps
module tb_check;
  localparam NCYC  = 700;   // enough for the whole test program
  localparam TRACE = 0;

  reg clk = 0, reset = 1;
  wire MemWrite;
  wire [31:0] WriteData, DataAdr, ReadData, PCW, Result, ALUResultW, WriteDataW;

  pl_riscv_cpu dut (.clk(clk), .reset(reset),
      .Ext_MemWrite(1'b0), .Ext_WriteData(32'b0), .Ext_DataAdr(32'b0),
      .MemWrite(MemWrite), .WriteData(WriteData), .DataAdr(DataAdr), .ReadData(ReadData),
      .PCW(PCW), .Result(Result), .ALUResultW(ALUResultW), .WriteDataW(WriteDataW));

  always #5 clk = ~clk;

  // expected final values; x = don't care
  reg [31:0] exp_val [0:31];
  reg        exp_chk [0:31];
  integer i, errors;

  always @(posedge clk)
    if (dut.MemWrite)
      $display("t=%0t  STORE  addr=%h  data=%h  funct3=%b",
               $time, dut.DataAdr, dut.WriteData, dut.rvcpu.funct3);

  task expect_reg(input integer r, input [31:0] v);
    begin exp_val[r] = v; exp_chk[r] = 1'b1; end
  endtask

  initial begin
    for (i = 0; i < 32; i = i + 1) exp_chk[i] = 1'b0;
    expect_reg(4,  32'h0000000a);  expect_reg(5,  32'h00000000);  expect_reg(6,  32'h00000005);
    expect_reg(20, 32'h00000000);  expect_reg(21, 32'h00000001);  expect_reg(22, 32'h00000000);
    expect_reg(23, 32'h00000001);  expect_reg(24, 32'h00000000);  expect_reg(25, 32'h00000001);
    expect_reg(26, 32'h00000001);  expect_reg(27, 32'hfffffffd);  expect_reg(28, 32'h00000010);
    expect_reg(29, 32'h00000001);  expect_reg(30, 32'h0000fffd);  expect_reg(31, 32'h000001c0);

    repeat (3) @(posedge clk);
    #1 reset = 0;
    repeat (NCYC) begin
      @(posedge clk);
      if (TRACE)
        $display("PC=%h  InstrD=%h  | WB: RegWriteW=%b RdW=%0d Result=%h",
                 dut.rvcpu.dp.PCF, dut.rvcpu.dp.InstrD,
                 dut.rvcpu.dp.RegWriteW, dut.rvcpu.dp.RdW, Result);
    end

    errors = 0;
    for (i = 0; i < 32; i = i + 1)
      if (exp_chk[i] && dut.rvcpu.dp.decode.rf.reg_file_arr[i] !== exp_val[i]) begin
        $display("FAIL x%0d: expected %h, got %h", i, exp_val[i], dut.rvcpu.dp.decode.rf.reg_file_arr[i]);
        errors = errors + 1;
      end
    if (errors == 0) $display("PASS: all checked registers match");
    else             $display("%0d register(s) wrong", errors);
    $finish;
  end
endmodule
