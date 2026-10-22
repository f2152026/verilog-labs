// Autograder testbench for lab03 task5.
//
// Clears sync_counter4, then applies 20 rising clock edges (period 400 ns, the same
// as Task 4). Just before every rising edge the count is read and checked.
`timescale 1ns/1ps
module tb;
  parameter T = 400;

  reg clk = 0, clr_n = 1;
  wire [3:0] q;

  sync_counter4 DUT (.clk(clk), .clr_n(clr_n), .q(q));


  // clear for 100 ns, then the clock starts
  initial begin
    #1   clr_n = 0;
    #99  clr_n = 1;
    #20  forever #(T/2.0) clk = ~clk;
  end

  integer n, err = 0;
  initial begin
    $timeformat(-9, 0, " ns", 9);
    for (n = 1; n <= 20; n = n + 1) begin
      @(posedge clk);                       // the counter counts here ...
      #(T - 1);                             // ... and is read 1 ns before the next edge
      $display("%t  edges=%2d | count = %b (%2d)", $time, n, q, q);
      if (q !== n % 16) err = err + 1;
    end
    if (err == 0) $display("ALL_TASK5_COUNTS_CORRECT");
    else $display("WRONG COUNTS: %0d", err);
    $finish;
  end
endmodule
