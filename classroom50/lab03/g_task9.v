// Autograder testbench for lab03 task9: skew_shift with N = 0, 1 must shift correctly;
// with N = 4 the second flip-flop catches the new bit in the same cycle.
`timescale 1ns/1ps
module tb;
  parameter T = 400;
  reg clk = 0, clr_n = 1, d = 0;
  wire q1a, q2a, q1b, q2b, q1c, q2c;
  skew_shift #(.N(0)) S0 (.clk(clk), .clr_n(clr_n), .d(d), .q1(q1a), .q2(q2a));
  skew_shift #(.N(1)) S1 (.clk(clk), .clr_n(clr_n), .d(d), .q1(q1b), .q2(q2b));
  skew_shift #(.N(4)) S4 (.clk(clk), .clr_n(clr_n), .d(d), .q1(q1c), .q2(q2c));
  initial begin
    #1 clr_n = 0; #99 clr_n = 1;
    #20 forever #(T/2.0) clk = ~clk;
  end
  reg [9:0] pattern = 10'b0110100111;
  reg [1:0] hist = 2'b00;
  integer n, err = 0;
  initial begin
    for (n = 0; n < 12; n = n + 1) begin
      @(negedge clk) d = (n < 10) ? pattern[9-n] : 1'b0;
      @(posedge clk) hist = {hist[0], d};
      #(T/2 - 1);
      if (q2a !== hist[1] || q2b !== hist[1]) begin err = err + 1; $display("FAIL edge %0d: N=0 q2=%b, N=1 q2=%b, expected %b", n+1, q2a, q2b, hist[1]); end
      if (q2c !== hist[0]) begin err = err + 1; $display("FAIL edge %0d: N=4 q2=%b, expected race-through %b", n+1, q2c, hist[0]); end
    end
    if (err == 0) $display("TASK9_PASSED");
    $finish;
  end
endmodule
