// tb.v -- Given, do not modify.
//
// Five copies of skew_shift, with N = 0, 1, 2, 3, 4 buffers on the second clock,
// all receive the same clock and the same serial data d. d changes on the FALLING
// clock edge, far from the rising edges. A correct two-stage shift register gives
// q2 = the value d had two rising edges ago.
`timescale 1ns/1ps
module tb;
  parameter T = 400;
  reg clk = 0, clr_n = 1, d = 0;
  wire [4:0] q1, q2;

  skew_shift #(.N(0)) S0 (.clk(clk), .clr_n(clr_n), .d(d), .q1(q1[0]), .q2(q2[0]));
  skew_shift #(.N(1)) S1 (.clk(clk), .clr_n(clr_n), .d(d), .q1(q1[1]), .q2(q2[1]));
  skew_shift #(.N(2)) S2 (.clk(clk), .clr_n(clr_n), .d(d), .q1(q1[2]), .q2(q2[2]));
  skew_shift #(.N(3)) S3 (.clk(clk), .clr_n(clr_n), .d(d), .q1(q1[3]), .q2(q2[3]));
  skew_shift #(.N(4)) S4 (.clk(clk), .clr_n(clr_n), .d(d), .q1(q1[4]), .q2(q2[4]));

  string vcd_file;
  initial begin
    if ($value$plusargs("vcd=%s", vcd_file)) begin
      $dumpfile(vcd_file);
      $dumpvars(0, tb);
    end
  end

  // clear for 100 ns, then the clock starts
  initial begin
    #1   clr_n = 0;
    #99  clr_n = 1;
    #20  forever #(T/2.0) clk = ~clk;
  end

  reg [9:0] pattern = 10'b0110100111;   // sent first bit first (MSB first)
  reg [1:0] hist = 2'b00;               // d sampled at the last two rising edges
  integer n, k;
  initial begin
    $timeformat(-9, 0, " ns", 9);
    for (n = 0; n < 12; n = n + 1) begin
      @(negedge clk) d = (n < 10) ? pattern[9-n] : 1'b0;   // change d mid-cycle
      @(posedge clk) hist = {hist[0], d};
      #(T/2 - 1);
      $write("%t  edge %2d  d=%b | expected q2=%b | q2 for N=0..4:", $time, n+1, d, hist[1]);
      for (k = 0; k <= 4; k = k + 1) $write(" %b", q2[k]);
      $write("\n");
    end
    $finish;
  end
endmodule
