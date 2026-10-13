`timescale 1ns/1ns
// =====================================================================
// Mode-aware SPI master testbench with diagnostics.
// The slave is modelled independently of the DUT (standard Motorola modes):
//   leading edge  = first SCLK edge after idle, trailing edge = the other one
//   CPHA=0: slave samples MOSI on leading, shifts MISO out on trailing
//           (first MISO bit is already on the wire when CS falls)
//   CPHA=1: slave shifts MISO out on leading, samples MOSI on trailing
//
// Run one combination:
//   iverilog -g2012 -Ptb_modes.CPOL=1 -Ptb_modes.CPHA=1 -Ptb_modes.LSB=0 \
//            [-Ptb_modes.WORD=16 -Ptb_modes.HALF=3] t2a_spi.v tb_modes.v && vvp a.out
// Add  +trace  to vvp for an edge-by-edge log of the slave's view.
// =====================================================================
module tb_modes;
  parameter CPOL = 0, CPHA = 1, LSB = 1, WORD = 8, HALF = 5, NRAND = 10;
  localparam NV = 6 + NRAND;

  reg clk = 0, rst_n = 0, start = 0, miso = 0;
  reg [WORD-1:0] tx_data = 0;
  wire sclk, cs, mosi, busy;
  wire [WORD-1:0] rx;

  t2a_spi #(.CPOL(CPOL), .CPHA(CPHA), .LSB_FIRST(LSB),
            .SPI_WORD_LENGTH(WORD), .HALF_PERIOD(HALF))
    dut (.clk_50MHz(clk), .rst_n(rst_n), .start(start), .tx_data(tx_data),
         .miso_input(miso), .sclk_out(sclk), .cs_out(cs), .mosi_output(mosi),
         .rx_data(rx), .busy(busy));

  always #10 clk = ~clk;

  integer e_rx = 0, e_mosi = 0, e_pulses = 0, e_idle = 0, e_cs = 0, e_period = 0;
  integer w_cshold = 0;
  integer reports = 0;
  reg trace;
  initial trace = $test$plusargs("trace");

  function integer pos(input integer n);      // n-th transmitted bit -> index in word
    pos = LSB ? n : (WORD - 1 - n);
  endfunction

  // ---------------- slave model ----------------
  reg [WORD-1:0] slave_tx;
  reg seen [0:WORD-1];                        // MOSI sampled for n-th transmitted bit
  time seen_t [0:WORD-1];
  integer rx_cnt, tx_cnt, pulses, edges, j;
  time last_edge, cs_rise_t;
  reg active = 0;

  always @(negedge cs) begin
    active = 1; rx_cnt = 0; tx_cnt = 0; pulses = 0; edges = 0; last_edge = 0;
    for (j = 0; j < WORD; j = j + 1) begin seen[j] = 1'bx; seen_t[j] = 0; end
    if (CPHA == 0) begin miso = slave_tx[pos(0)]; tx_cnt = 1; end
    if (trace) $display("%0t  CS falls  (slave drives miso=%b)", $time, miso);
  end

  always @(posedge cs) begin
    cs_rise_t = $time;
    #1;
    if (cs_rise_t - last_edge < 20) w_cshold = w_cshold + 1;  // CS rose <1 clk after last SCLK edge
    active = 0;
    if (trace) $display("%0t  CS rises", cs_rise_t);
  end

  always @(sclk) if (active) begin
    if (last_edge != 0 && ($time - last_edge) != HALF*20) e_period = e_period + 1;
    last_edge = $time; edges = edges + 1;
    if (sclk !== CPOL) begin                  // ---- leading edge
      pulses = pulses + 1;
      if (CPHA == 0) begin
        if (rx_cnt < WORD) begin seen[rx_cnt] = mosi; seen_t[rx_cnt] = $time; rx_cnt = rx_cnt + 1; end
        if (trace) $display("%0t  leading : slave SAMPLES mosi=%b (bit #%0d)", $time, mosi, rx_cnt-1);
      end else begin
        if (tx_cnt < WORD) miso = slave_tx[pos(tx_cnt)];
        if (trace) $display("%0t  leading : slave DRIVES miso=%b (bit #%0d)", $time, miso, tx_cnt);
        tx_cnt = tx_cnt + 1;
      end
    end else begin                            // ---- trailing edge
      if (CPHA == 0) begin
        if (tx_cnt < WORD) miso = slave_tx[pos(tx_cnt)];
        if (trace) $display("%0t  trailing: slave DRIVES miso=%b (bit #%0d)", $time, miso, tx_cnt);
        tx_cnt = tx_cnt + 1;
      end else begin
        if (rx_cnt < WORD) begin seen[rx_cnt] = mosi; seen_t[rx_cnt] = $time; rx_cnt = rx_cnt + 1; end
        if (trace) $display("%0t  trailing: slave SAMPLES mosi=%b (bit #%0d)", $time, mosi, rx_cnt-1);
      end
    end
  end

  // idle level and cs/busy relationship, sampled 1ns after every clock toggle
  always @(clk) begin
    #1;
    if (rst_n) begin
      if (cs === 1'b1 && sclk !== CPOL) e_idle = e_idle + 1;
      if (cs !== ~busy)                 e_cs   = e_cs + 1;
    end
  end

  // ---------------- driver + diagnostics ----------------
  integer k, n, bad;
  reg [WORD-1:0] tv [0:NV-1];
  reg [WORD-1:0] sv [0:NV-1];
  reg [WORD-1:0] mask;
  reg expb;
  reg h_ahead, h_behind, h_stale;
  integer seed = 32'h5eed;

  task check(input [WORD-1:0] t, input [WORD-1:0] s, input integer idx);
    reg f_rx, f_mosi, f_pulses;
    begin
      mask = {WORD{1'b1}};
      f_rx = (rx !== s);
      f_pulses = (pulses != WORD);
      f_mosi = 0; h_ahead = 1; h_behind = 1;
      for (n = 0; n < WORD; n = n + 1) begin
        if (seen[n] !== t[pos(n)]) f_mosi = 1;
        if (n < WORD-1 && n < rx_cnt)   if (seen[n]   !== t[pos(n+1)]) h_ahead  = 0;  // slave saw the NEXT bit
        if (n < WORD-1 && n+1 < rx_cnt) if (seen[n+1] !== t[pos(n)])   h_behind = 0;  // slave saw the PREVIOUS bit
      end
      h_stale = (rx === (LSB ? ((s << 1) & mask) : (s >> 1)));  // last sample missing from rx_data
      if (f_rx)     e_rx     = e_rx + 1;
      if (f_mosi)   e_mosi   = e_mosi + 1;
      if (f_pulses) e_pulses = e_pulses + 1;
      if ((f_rx || f_mosi || f_pulses) && reports < 3) begin
        reports = reports + 1;
        $display("  vector %0d: tx=%h slave_tx=%h", idx, t, s);
        if (f_pulses)
          $display("    SCLK pulses : got %0d, expected %0d  -> transfer ends %s", pulses, WORD,
                   (pulses < WORD) ? "TOO EARLY (check transfer_complete)" : "too late");
        if (f_mosi) begin
          $write("    MOSI bits (tx order) expected :"); for (n = 0; n < WORD; n = n + 1) $write(" %b", t[pos(n)]); $write("\n");
          $write("    MOSI bits seen by slave       :"); for (n = 0; n < WORD; n = n + 1) $write(" %b", (n < rx_cnt) ? seen[n] : 1'bx); $write("   (%0d samples taken)\n", rx_cnt);
          bad = -1; for (n = WORD-1; n >= 0; n = n - 1) if (seen[n] !== t[pos(n)]) bad = n;
          $display("    first wrong MOSI bit: #%0d", bad);
          if (h_ahead)  $display("    HINT: slave sees each bit one position EARLY -> MOSI shifts to the next bit before the slave's sample edge (first-bit / preload vs. drive edge)");
          if (h_behind) $display("    HINT: slave sees each bit one position LATE -> MOSI shifts after the sample edge");
        end
        if (f_rx) begin
          $display("    rx_data=%h expected=%h xor=%h", rx, s, rx ^ s);
          if (h_stale) $display("    HINT: rx_data == expected shifted by one -> rx_data latched BEFORE the final sample landed in recv");
        end
      end
    end
  endtask

  task xfer(input [WORD-1:0] t, input [WORD-1:0] s, input integer idx);
    begin
      slave_tx = s;
      @(negedge clk); tx_data = t; start = 1;
      @(negedge clk); start = 0;
      @(posedge busy); @(negedge busy);
      repeat (3) @(posedge clk);
      #1 check(t, s, idx);
    end
  endtask

  initial begin
    tv[0]=8'h00; sv[0]=8'hFF;  tv[1]=8'hFF; sv[1]=8'h00;
    tv[2]=8'hA5; sv[2]=8'h5A;  tv[3]=8'h5A; sv[3]=8'hA5;
    tv[4]=8'h81; sv[4]=8'h3C;  tv[5]=8'h3C; sv[5]=8'h81;
    for (k = 6; k < NV; k = k + 1) begin tv[k] = $random(seed); sv[k] = $random(seed); end
    #105 rst_n = 1;
    repeat (4) @(posedge clk);
    for (k = 0; k < NV; k = k + 1) begin xfer(tv[k], sv[k], k); repeat (5) @(posedge clk); end
    $display("MODE CPOL=%0d CPHA=%0d LSB=%0d W=%0d H=%0d : %s  [rx=%0d mosi=%0d pulses=%0d idle=%0d cs/busy=%0d period=%0d]  warn(cs<1clk after last SCLK edge)=%0d",
      CPOL, CPHA, LSB, WORD, HALF,
      (e_rx+e_mosi+e_pulses+e_idle+e_cs+e_period)==0 ? "PASS" : "FAIL",
      e_rx, e_mosi, e_pulses, e_idle, e_cs, e_period, w_cshold);
    $finish;
  end
  initial begin #2000000; $display("MODE CPOL=%0d CPHA=%0d LSB=%0d W=%0d H=%0d : TIMEOUT (busy never rose/fell)", CPOL, CPHA, LSB, WORD, HALF); $finish; end
endmodule
