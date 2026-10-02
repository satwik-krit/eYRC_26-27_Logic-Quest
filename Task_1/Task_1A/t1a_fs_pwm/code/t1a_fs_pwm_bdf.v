// Copyright (C) 2020  Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions 
// and other software and tools, and any partner logic 
// functions, and any output files from any of the foregoing 
// (including device programming or simulation files), and any 
// associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License 
// Subscription Agreement, the Intel Quartus Prime License Agreement,
// the Intel FPGA IP License Agreement, or other applicable license
// agreement, including, without limitation, that your use is for
// the sole purpose of programming logic devices manufactured by
// Intel and sold by Intel or its authorized distributors.  Please
// refer to the applicable agreement for further details, at
// https://fpgasoftware.intel.com/eula.

// PROGRAM		"Quartus Prime"
// VERSION		"Version 20.1.0 Build 711 06/05/2020 SJ Lite Edition"
// CREATED		"Mon Sep 28 23:42:24 2026"

module t1a_fs_pwm_bdf(
	reset_n,
	clk_50MHz,
	pulse_width,
	clk_5MHz,
	clk_500Hz,
	pwm_signal
);


input wire	reset_n;
input wire	clk_50MHz;
input wire	[4:0] pulse_width;
output wire	clk_5MHz;
output wire	clk_500Hz;
output wire	pwm_signal;

wire	SYNTHESIZED_WIRE_0;

assign	clk_5MHz = SYNTHESIZED_WIRE_0;




frequency_scaling	b2v_inst(
	.clk_50MHz(clk_50MHz),
	.reset_n(reset_n),
	.clk_5MHz(SYNTHESIZED_WIRE_0));


pwm_generator	b2v_inst1(
	.clk_5MHz(SYNTHESIZED_WIRE_0),
	.reset_n(reset_n),
	.pulse_width(pulse_width),
	.clk_500Hz(clk_500Hz),
	.pwm_signal(pwm_signal));


endmodule
