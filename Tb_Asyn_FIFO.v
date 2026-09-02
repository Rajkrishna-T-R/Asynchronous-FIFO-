`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.09.2026 09:37:10
// Design Name: 
// Module Name: Tb_Asyn_FIFO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Tb_Asyn_FIFO;
//////////////////////////////////////////////////////////////////////////////////
// Testbench for : Asyn_FIFO
// Style         : Simple, task based, self-checking (Verilog-2001)
//
// Covers :
//   1. Reset behaviour (both clock domains)
//   2. Full flag + overflow protection (writing while full is rejected)
//   3. Empty flag + underflow protection (reading while empty is rejected)
//   4. Continuous overlapped write/read across independent async clocks
//   5. A scoreboard that hooks onto the DUT's own write_en/read_en to
//      verify every data word comes out in the same order it went in
//
// Clocks  : wclk = 10ns period (100MHz)   -- write side is the faster clock
//           rclk = 16ns period (62.5MHz)  -- read side is the slower clock
// Burst   : 8 transactions per burst (== FIFO_DEPTH), continuous test runs
//           4 bursts back to back (32 transactions) to exercise pointer wrap
//////////////////////////////////////////////////////////////////////////////////


    parameter DATA_WIDTH = 8;
    parameter FIFO_DEPTH = 8;
    parameter BURST_SIZE = 8;      // one FIFO worth per burst
    parameter GOLD_DEPTH = 1024;   // scoreboard queue depth 

    //----------------------------------------------------------------
    // DUT signals
    //----------------------------------------------------------------
    reg                     rclk;
    reg                     wclk;
    reg                     rst_bar;
    reg  [DATA_WIDTH-1:0]   data_in;
    reg                     write_ready;
    reg                     read_ready;
    wire                    fifo_full;
    wire                    fifo_empty;
    wire [DATA_WIDTH-1:0]   data_out;

    //----------------------------------------------------------------
    // Bookkeeping / scoreboard storage
    //----------------------------------------------------------------
    integer error_count;
    integer match_count;
    integer accepted_write_count;
    integer accepted_read_count;
    integer reject_write_count;   // write attempted while full
    integer reject_read_count;    // read attempted while empty

    reg [DATA_WIDTH-1:0] gold_q [0:GOLD_DEPTH-1];
    integer g_head;
    integer g_tail;
    reg [DATA_WIDTH-1:0] expected_val;
    reg                  pending_check;

    integer wi, ri; // loop indices for the two fork/join threads

    parameter wclk_period=10;
    
    parameter rclk_period=16;    
    
    //----------------------------------------------------------------
    // DUT instantiation
    //----------------------------------------------------------------
    Asyn_FIFO #(
        .data_width (DATA_WIDTH),
        .FIFO_depth (FIFO_DEPTH)
    ) dut (
        .rclk        (rclk),
        .rst_bar     (rst_bar),
        .data_in     (data_in),
        .wclk        (wclk),
        .write_ready (write_ready),
        .read_ready  (read_ready),
        .fifo_full   (fifo_full),
        .fifo_empty  (fifo_empty),
        .data_out    (data_out)
    );

    //----------------------------------------------------------------
    // Clock generation - write side faster than read side
    //----------------------------------------------------------------
    initial wclk = 1'b0;
    always #5 wclk = ~wclk;   // 10ns period

    initial rclk = 1'b0;
    always #8 rclk = ~rclk;   // 16ns period

    //----------------------------------------------------------------
    // Init
    //----------------------------------------------------------------
    initial begin
        g_head               = 0;
        g_tail               = 0;
        error_count          = 0;
        match_count          = 0;
        accepted_write_count = 0;
        accepted_read_count  = 0;
        reject_write_count   = 0;
        reject_read_count    = 0;
        pending_check        = 1'b0;
    end

    //----------------------------------------------------------------
    // Scoreboard : pushes/pops are driven off the DUT's OWN write_en /
    // read_en signals (hierarchical reference), so the check reflects
    // exactly what the DUT actually did, not what we merely requested.
    //----------------------------------------------------------------
    always @(posedge wclk) begin
        if (dut.write_en) begin
            gold_q[g_tail % GOLD_DEPTH] <= data_in;
            g_tail                      <= g_tail + 1;
            accepted_write_count        <= accepted_write_count + 1;
        end
        if (write_ready && fifo_full) begin
            reject_write_count <= reject_write_count + 1;
        end
    end

    always @(posedge rclk) begin
        if (dut.read_en) begin
            expected_val        <= gold_q[g_head % GOLD_DEPTH];
            g_head               <= g_head + 1;
            accepted_read_count  <= accepted_read_count + 1;
            pending_check        <= 1'b1;
        end else begin
            pending_check <= 1'b0;
        end
        if (read_ready && fifo_empty) begin
            reject_read_count <= reject_read_count + 1;
        end
    end

    // Compare half a cycle later, once data_out and expected_val have
    // both settled from the posedge that produced them.
    always @(negedge rclk) begin
        if (pending_check) begin
            if (data_out !== expected_val) begin
                $display("[%0t] SCOREBOARD *** MISMATCH *** expected=%0h got=%0h",
                          $time, expected_val, data_out);
                error_count <= error_count + 1;
            end else begin
                match_count <= match_count + 1;
            end
        end
    end

    //----------------------------------------------------------------
    // Basic drive tasks - each holds the handshake signal for exactly
    // one clock of its own domain (negedge -> negedge spans one posedge)
    //----------------------------------------------------------------
    task wr_pulse(input [DATA_WIDTH-1:0] d);
        begin
            @(negedge wclk);
            data_in     = d;
            write_ready = 1'b1;
            @(negedge wclk);
            write_ready = 1'b0;
        end
    endtask

    task rd_pulse;
        begin
            @(negedge rclk);
            read_ready = 1'b1;
            @(negedge rclk);
            read_ready = 1'b0;
        end
    endtask

    task apply_reset;
        begin
            rst_bar     = 1'b0;
            write_ready = 1'b0;
            read_ready  = 1'b0;
            data_in     = {DATA_WIDTH{1'b0}};
            repeat (3) @(posedge wclk);
            repeat (3) @(posedge rclk);
            rst_bar     = 1'b1;
            repeat (4) @(posedge wclk);   // let the 2-flop synchronizers clear
            repeat (4) @(posedge rclk);
        end
    endtask

    //----------------------------------------------------------------
    // TEST 1 : Reset
    //----------------------------------------------------------------
    task test_reset;
        begin
            $display("\n---- TEST 1 : RESET ----");
            apply_reset;

            if (fifo_empty !== 1'b1) begin
                $display("ERROR: fifo_empty not set after reset");
                error_count = error_count + 1;
            end else
                $display("PASS: fifo_empty asserted after reset");

            if (fifo_full !== 1'b0) begin
                $display("ERROR: fifo_full incorrectly set after reset");
                error_count = error_count + 1;
            end else
                $display("PASS: fifo_full deasserted after reset");

            if (dut.wr_ptr !== 0 || dut.rd_ptr !== 0) begin
                $display("ERROR: pointers not cleared by reset");
                error_count = error_count + 1;
            end else
                $display("PASS: read/write pointers cleared by reset");
        end
    endtask

    //----------------------------------------------------------------
    // TEST 2 : Fill to FULL, then attempt an overflow write
    //----------------------------------------------------------------
    task test_full_and_overflow;
        integer k;
        begin
            $display("\n---- TEST 2 : FULL FLAG + OVERFLOW PROTECTION ----");
            apply_reset;

            for (k = 0; k <= FIFO_DEPTH-1; k = k + 1)
                wr_pulse($random);
                
            #(wclk_period);
            #(wclk_period);

            @(negedge wclk);
            if (fifo_full !== 1'b1) begin
                $display("ERROR: fifo_full not set after %0d writes", FIFO_DEPTH);
                error_count = error_count + 1;
            end else
                $display("PASS: fifo_full asserted after filling the FIFO (%0d entries)", FIFO_DEPTH);

          //   one extra write while full - must be silently rejected
             wr_pulse($random);
          if (fifo_full !== 1'b1) begin
                $display("ERROR: fifo_full flag disturbed by overflow attempt");
                error_count = error_count + 1;
            end else
                $display("PASS: overflow write correctly rejected, fifo_full still asserted");
         
            $display("INFO: total rejected write attempts so far = %0d", reject_write_count);

            // drain fully - scoreboard confirms exactly the 8 written values come back
            for (k = 0; k <= FIFO_DEPTH-1; k = k + 1)
                rd_pulse;
        end
    endtask

    //----------------------------------------------------------------
    // TEST 3 : Empty flag + underflow protection
    //----------------------------------------------------------------
    task test_empty_condition;
        begin
            $display("\n---- TEST 3 : EMPTY FLAG + UNDERFLOW PROTECTION ----");
            apply_reset;

            if (fifo_empty !== 1'b1) begin
                $display("ERROR: FIFO not empty after reset");
                error_count = error_count + 1;
            end else
                $display("PASS: FIFO empty after reset");

            rd_pulse; // read while empty - must be rejected
            if (fifo_empty !== 1'b1) begin
                $display("ERROR: fifo_empty disturbed by invalid read attempt");
                error_count = error_count + 1;
            end else
                $display("PASS: read correctly blocked while empty");

            wr_pulse(8'hA5);
            repeat (4) @(posedge rclk); // let the gray pointer cross into the read domain
            if (fifo_empty !== 1'b0) begin
                $display("ERROR: fifo_empty should deassert after one write");
                error_count = error_count + 1;
            end else
                $display("PASS: fifo_empty deasserted after a single write");

            rd_pulse;
            repeat (2) @(posedge rclk);
            if (fifo_empty !== 1'b1) begin
                $display("ERROR: fifo_empty should reassert after draining the only entry");
                error_count = error_count + 1;
            end else
                $display("PASS: fifo_empty reasserted after reading back the only entry");
        end
    endtask

    //----------------------------------------------------------------
    // TEST 4 : Continuous overlapped write / read across async clocks
    //----------------------------------------------------------------
    task test_continuous_write_read;
        begin
            $display("\n---- TEST 4 : CONTINUOUS WRITE / READ (async, %0d bursts of %0d) ----", 4, BURST_SIZE);
            apply_reset;
            fork
                begin : wr_thread
                    for (wi = 0; wi < 4*BURST_SIZE; wi = wi + 1)
                        wr_pulse($random);
                end
                begin : rd_thread
                    repeat (6) @(posedge rclk); // let a little data build up first
                    for (ri = 0; ri < 4*BURST_SIZE; ri = ri + 1)
                        rd_pulse;
                end
            join
            // drain anything still left behind
            repeat (FIFO_DEPTH) rd_pulse;
        end
    endtask

    //----------------------------------------------------------------
    // Main sequence
    //----------------------------------------------------------------
    initial begin
        $display("=========================================================");
        $display(" Asynchronous FIFO Testbench  (depth=%0d, width=%0d)", FIFO_DEPTH, DATA_WIDTH);
        $display(" wclk = 10ns period, rclk = 16ns period");
        $display("=========================================================");

        test_reset;
        test_full_and_overflow;
        test_empty_condition;
        test_continuous_write_read;

        repeat (5) @(posedge rclk); // let the last pending scoreboard compare finish

        $display("\n=========================================================");
        $display(" TEST SUMMARY");
        $display("  Accepted writes              : %0d", accepted_write_count);
        $display("  Accepted reads                : %0d", accepted_read_count);
        $display("  Rejected writes (FIFO full)   : %0d", reject_write_count);
        $display("  Rejected reads  (FIFO empty)  : %0d", reject_read_count);
        $display("  Scoreboard matches            : %0d", match_count);
        $display("  Scoreboard mismatches/errors  : %0d", error_count);
        if (error_count == 0)
            $display("  RESULT : ALL TESTS PASSED");
        else
            $display("  RESULT : *** %0d ERROR(S) DETECTED ***", error_count);
        $display("=========================================================");

        $finish;
    end

endmodule
