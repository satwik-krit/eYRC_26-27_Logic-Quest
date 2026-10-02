`timescale 1 ns/1 ns

module tb_1b;

// registers to send data
reg clk;
reg reset;
reg Ext_MemWrite;
reg [31:0] Ext_WriteData, Ext_DataAdr;

// Wire Ouputs from Instantiated Modules
wire [31:0] WriteData, DataAdr, ReadData;
wire MemWrite;
wire [31:0] PC, Result;

// Initialize Top Module
t1_riscv_cpu uut (clk, reset, Ext_MemWrite, Ext_WriteData, Ext_DataAdr, MemWrite, WriteData, DataAdr, ReadData, PC, Result);

integer fault_instrs = 0, i = 0, fw = 0;

localparam TOTAL_CHECKS = 15;

// ===========================================================================
// This testbench can check either of the two programs shipped in code/, and
// the one it checks has to be the one instr_mem.v actually loads:
//
//   rv32i_test.hex   (default)   keep SECTION 2 active, leave SECTION 1
//                                commented out
//   rv32i_book.hex               comment out SECTION 2, uncomment SECTION 1
//
// Switch the matching $readmemh in code/instr_mem.v at the same time. The two
// programs use completely different addresses, so checking one of them while
// the other is loaded only reports nonsense.
// ===========================================================================

// generate clock to sequence tests
always begin
    clk <= 1; # 5; clk <= 0; # 5;
end

initial begin
    reset = 1;
    Ext_MemWrite = 0; Ext_DataAdr = 32'b0; Ext_WriteData = 32'b0; #10;
    reset = 0;
end

// write the verdict of the run into the transcript and into results.txt
task report_result;
    begin
        $display("Faulty Instructions => %d", fault_instrs);
        if (fault_instrs !== 0) begin
            fw = $fopen("results.txt","w");
            $fdisplay(fw, "%02h","Errors");
            $display("Error(s) encountered, please check your design!");
            $fclose(fw);
        end
        else begin
            fw = $fopen("results.txt","w");
            $fdisplay(fw, "%02h","No Errors");
            $display("No errors encountered, congratulations!");
            $fclose(fw);
        end
        $stop;
    end
endtask

// the run died before every check was reached, so count what is left as faulty
task report_early;
    begin
        $display("%0d of %0d checks were reached, the remaining %0d are counted as faulty",
                 i, TOTAL_CHECKS, TOTAL_CHECKS - i);
        fault_instrs = fault_instrs + (TOTAL_CHECKS - i);
        report_result;
    end
endtask

// ===========================================================================
// SECTION 1 - checks rv32i_book.hex, the text book program
//
// It has no lui/auipc/jalr in it, so it only tells you whether the CPU you
// were given still works: the program stores 7 into mem[96] and then 25 into
// mem[100], and any other write means it went wrong along the way.
// Uncomment the block below (and comment out SECTION 2) to use it.
// ===========================================================================

// test the book asm program
 //always @(negedge clk) begin
     //if(MemWrite && !reset) begin
       //  if(DataAdr === 100 & WriteData === 25) begin
     //        $display("Simulation succeeded");
   //          $stop;
 //        end
         //else if (DataAdr !== 96) begin
        //     $display("Simulation failed");
      //       $stop;
    //     end
  //   end
// end

// ===========================================================================
// SECTION 2 - checks rv32i_test.hex (default)
//
// This section only checks the instructions that main_decoder.v /
// alu_decoder.v / alu.v currently execute correctly
//   (addi, andi, ori, slti, add, sub, slt, or, and, sw, lw, beq)
// plus the three instructions under investigation, which are NOT decoded
// (their opcodes fall into main_decoder's "default" case -> all X controls):
//   lui, auipc, jalr
// Every other RV32I instruction has been removed from rv32i_test.s / .hex.
//
// rv32i_test.s runs the program straight through in normal order: no pass
// counter, no mid-simulation reset pulse, no dispatcher. Once an undecoded
// opcode executes, PCNext is driven to X and the core can never fetch
// correctly again (see main_decoder.v default case + mux2.v), so the checks
// after it are never reached in that run - fix the instructions in program
// order (lui, then auipc, then jalr) to see each one tested in turn. The
// watchdog at the bottom reports whatever was reached instead of letting the
// simulation run out with no verdict.
//
// Every checkpoint below is the address of the instruction being checked, as
// annotated in code/rv32i_test.s. BEQ is confirmed one instruction after the
// branch, at the add that copies x16 back, because that is where the loop
// having behaved becomes visible on Result.
// ===========================================================================

localparam ADDI_CHK  = 32'h0C;
localparam ANDI_CHK  = 32'h10;
localparam ORI_CHK   = 32'h14;
localparam SLTI_CHK  = 32'h18;

localparam ADD_CHK   = 32'h1C;
localparam SUB_CHK   = 32'h20;
localparam SLT_CHK   = 32'h24;
localparam OR_CHK    = 32'h28;
localparam AND_CHK   = 32'h2C;

localparam SW_CHK    = 32'h30;
localparam LW_CHK    = 32'h34;

localparam BEQ_IN    = 32'h44;
localparam BEQ_CHK   = 32'h50;

localparam LUI_CHK   = 32'h54;
localparam AUIPC_CHK = 32'h58;
localparam JALR_CHK  = 32'h5C;

// check results of trimmed RISC-V CPU test (from code/rv32i_test.s) rv32i_test.hex
always @(negedge clk) begin
    case(PC)
        ADDI_CHK : begin
            i = i + 1'b1;
            if(Result === 9) $display("1. addi implementation is correct ");
            else begin
                $display("1. addi implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        ANDI_CHK : begin
            i = i + 1'b1;
            if(Result === 1) $display("2. andi implementation is correct ");
            else begin
                $display("2. andi implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        ORI_CHK : begin
            i = i + 1'b1;
            if(Result === -1) $display("3. ori implementation is correct ");
            else begin
                $display("3. ori implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        SLTI_CHK : begin
            i = i + 1'b1;
            if(Result === 1) $display("4. slti implementation is correct ");
            else begin
                $display("4. slti implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        ADD_CHK : begin
            i = i + 1'b1;
            if(Result === 17) $display("5. add implementation is correct ");
            else begin
                $display("5. add implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        SUB_CHK : begin
            i = i + 1'b1;
            if(Result === 15) $display("6. sub implementation is correct ");
            else begin
                $display("6. sub implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        SLT_CHK : begin
            i = i + 1'b1;
            if(Result === 1) $display("7. slt implementation is correct ");
            else begin
                $display("7. slt implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        OR_CHK : begin
            i = i + 1'b1;
            if(Result === 17) $display("8. or implementation is correct ");
            else begin
                $display("8. or implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        AND_CHK : begin
            i = i + 1'b1;
            if(Result === 0) $display("9. and implementation is correct ");
            else begin
                $display("9. and implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        SW_CHK : begin
            i = i + 1'b1;
            if(MemWrite && !reset && DataAdr === 40 & WriteData === 16)
                $display("10. sw implementation is correct");
            else begin
                $display("10. sw implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        LW_CHK : begin
            i = i + 1'b1;
            if(DataAdr === 40 & Result === 16) $display("11. lw implementation is correct");
            else begin
                $display("11. lw implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        // the loop body runs twice, x15 counts the iterations
        BEQ_IN : begin
            if(Result <= 2) $display("12. beq is executing");
            else begin
                $display("beq struck in loop");
                report_early;
            end
        end

        BEQ_CHK : begin
            i = i + 1'b1;
            if(Result === 4) $display("12. beq implementation is correct ");
            else begin
                $display("12. beq implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        LUI_CHK : begin
            i = i + 1'b1;
            if(Result === 32'h02000000) $display("13. lui implementation is correct ");
            else begin
                $display("13. lui implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        AUIPC_CHK : begin
            i = i + 1'b1;
            if(Result === 32'h02000058) $display("14. auipc implementation is correct ");
            else begin
                $display("14. auipc implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

        JALR_CHK : begin
            i = i + 1'b1;
            if (Result === 32'h60) $display("15. jalr implementation is correct ");
            else begin
                $display("15. jalr implementation is incorrect");
                fault_instrs = fault_instrs + 1'b1;
            end
        end

    endcase
end

// every check reached, report and stop
always @(negedge clk) begin
    if (i >= TOTAL_CHECKS) report_result;
end

// watchdog: an undecoded lui/auipc/jalr takes PCNext to X and the core stops
// fetching, so the checks that follow it are never reached. Report what was
// reached rather than finishing the run with no verdict at all.
initial begin
    #1000;
    $display("Simulation stopped early, the CPU is no longer fetching (PC = %h)", PC);
    report_early;
end
endmodule