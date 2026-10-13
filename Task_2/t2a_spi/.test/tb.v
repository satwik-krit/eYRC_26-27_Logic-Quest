`timescale 1ns/1ns

// No Teams are allowed to edit this file.

module tb;

    localparam CLK_PERIOD   = 20;   // ns, 50MHz
    localparam WORD         = 8;
    localparam HALF         = 5;    // HALF_PERIOD override -> SCLK = 50MHz/(2*5) = 5MHz

    reg clk_50MHz;
    reg reset_n;

    reg              start;
    reg  [WORD-1:0]  tx_data;
    reg              miso_input;

    wire             sclk_out;
    wire             cs_out;
    wire             mosi_output;
    wire [WORD-1:0]  rx_data;
    wire             busy;

    reg  [WORD-1:0]  expected_rx_data;   // what the modeled slave drives back this vector
    reg  [WORD-1:0]  mosi_shadow_reg;    // what the modeled slave saw on MOSI, bit by bit

    reg expected_sclk;                  // golden model of the sclk_out waveform
    integer sclk_gen_bit;               // loop var for the expected_sclk generator
    integer error_count;
    integer fw, i;
    integer mosi_bit_idx;              // next MOSI bit position the modeled slave will sample
    integer miso_bit_idx;              // next MISO bit position the modeled slave will drive

    t2a_spi #(
        .CPOL(1'b0),
        .CPHA(1'b0),
        .LSB_FIRST(1'b0),
        .SPI_WORD_LENGTH(WORD),
        .HALF_PERIOD(HALF)
    ) uut (
        .clk_50MHz(clk_50MHz),
        .rst_n(reset_n),
        .start(start),
        .tx_data(tx_data),
        .miso_input(miso_input),
        .sclk_out(sclk_out),
        .cs_out(cs_out),
        .mosi_output(mosi_output),
        .rx_data(rx_data),
        .busy(busy)
    );

    initial begin
        error_count = 0; fw = 0; i = 0;
        clk_50MHz = 0; reset_n = 0; start = 0; tx_data = 0; miso_input = 0;
        expected_rx_data = 0; mosi_shadow_reg = 0; expected_sclk = 1'b0;
        mosi_bit_idx = WORD - 1; miso_bit_idx = WORD - 1;
        #105;
        reset_n = 1;
    end

    always begin
        clk_50MHz = ~clk_50MHz; #10;
    end

    always @(posedge clk_50MHz or negedge reset_n) begin
        if (!reset_n) begin
            tx_data <= 8'h00;
            start   <= 1'b0;
        end else begin
            tx_data = 8'h00; expected_rx_data = 8'hFF; start = 1; #20; start = 0; #2000;
            tx_data = 8'hFF; expected_rx_data = 8'h00; start = 1; #20; start = 0; #2000;
            tx_data = 8'hA5; expected_rx_data = 8'h5A; start = 1; #20; start = 0; #2000;
            tx_data = 8'h5A; expected_rx_data = 8'hA5; start = 1; #20; start = 0; #2000;
            tx_data = 8'h81; expected_rx_data = 8'h3C; start = 1; #20; start = 0; #2000;
            tx_data = 8'h3C; expected_rx_data = 8'h81; start = 1; #20; start = 0; #2000;
        end
    end

    always @(negedge cs_out) begin
        mosi_bit_idx = WORD - 1;
        mosi_shadow_reg = 0;
        miso_input   = expected_rx_data[WORD - 1];
        miso_bit_idx = WORD - 2;
    end

    always @(posedge sclk_out) begin
        mosi_shadow_reg[mosi_bit_idx] = mosi_output;
        if (mosi_bit_idx > 0)
            mosi_bit_idx = mosi_bit_idx - 1;
    end

    always @(negedge cs_out) begin
        expected_sclk = 1'b0;
        #((HALF + 1) * CLK_PERIOD);
        for (sclk_gen_bit = 0; sclk_gen_bit < WORD; sclk_gen_bit = sclk_gen_bit + 1) begin
            expected_sclk = 1'b1;
            #(HALF * CLK_PERIOD);
            expected_sclk = 1'b0;
            #(HALF * CLK_PERIOD);
        end
    end

    always @(negedge sclk_out) begin
        if (miso_bit_idx >= 0) begin
            miso_input   = expected_rx_data[miso_bit_idx];
            miso_bit_idx = miso_bit_idx - 1;
        end
    end

    always @(clk_50MHz) begin
        #1;
        if (cs_out !== ~busy) begin
            error_count   = error_count + 1'b1;
        end
        if (sclk_out !== expected_sclk) begin
            error_count = error_count + 1'b1;
        end
    end

    always @(clk_50MHz) begin
        #1;
        if (mosi_shadow_reg !== tx_data) begin
            error_count         = error_count + 1;
        end

        if (rx_data !== expected_rx_data) begin
            error_count       = error_count + 1;
        end 

        i = i + 1;

        if (i == 6) begin
            if (error_count !== 0) begin
                fw = $fopen("results.txt", "w");
                $fdisplay(fw, "%02h", "Errors");
                $display("Error(s) encountered, please check your design!");
                $fclose(fw);
            end else begin
                fw = $fopen("results.txt", "w");
                $fdisplay(fw, "%02h", "No Errors");
                $display("No errors encountered, congratulations!");
                $fclose(fw);
            end
            i = 0;
            #50000;
            $stop;
        end
    end

endmodule
