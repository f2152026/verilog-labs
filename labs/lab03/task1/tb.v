// tb.v -- Given, do not modify.
//
// Drives all the shift registers with the same clock and the same serial input d,
// and drives both swap modules with the same load/ain/bin.
// Inputs change only on the FALLING clock edge, half a period away from the
// rising edge where the flip-flops act. Every line is printed just after a
// rising edge.
`timescale 1ns/1ps
module tb;
  reg clk = 0, d = 0, load = 1;
  reg [3:0] ain = 4'd3, bin = 4'd12;
  wire a1, a2, a3, b1, b2, b3, c1, c2, c3, e1, e2, e3;
  wire [3:0] p, r, sa_nb, sb_nb, sa_b, sb_b;

  shift_nb    UA (.clk(clk), .d(d), .q1(a1), .q2(a2), .q3(a3));
  shift_b     UB (.clk(clk), .d(d), .q1(b1), .q2(b2), .q3(b3));
  shift_b_rev UC (.clk(clk), .d(d), .q1(c1), .q2(c2), .q3(c3));
  shift_3blk  UD (.clk(clk), .d(d), .q1(e1), .q2(e2), .q3(e3));
  shift4_nb   UP (.clk(clk), .d(d), .q(p));
  shift4_b    UR (.clk(clk), .d(d), .q(r));
  swap_nb     SN (.clk(clk), .load(load), .ain(ain), .bin(bin), .a(sa_nb), .b(sb_nb));
  swap_b      SB (.clk(clk), .load(load), .ain(ain), .bin(bin), .a(sa_b),  .b(sb_b));

  string vcd_file;
  initial begin
    if ($value$plusargs("vcd=%s", vcd_file)) begin
      $dumpfile(vcd_file);
      $dumpvars(0, tb);
    end
  end

  always #5 clk = ~clk;                      // period 10, rising edges at 5, 15, 25, ...

  reg [7:0] pattern = 8'b1011_0010;          // serial input, sent MSB first
  integer n;
  initial begin
    $timeformat(-9, 0, "", 4);
    $display("                                                    shift4_nb shift4_b\n time  d | A:q1q2q3  B:q1q2q3  C:q1q2q3  D:q1q2q3 | q[0..3]   q[0..3]  | swap_nb a,b  swap_b a,b");
    for (n = 0; n < 10; n = n + 1) begin
      d = (n < 8) ? pattern[7-n] : 1'b0;
      if (n == 1) load = 0;                  // load on the first edge, swap on every later edge
      @(posedge clk); #1;
      $display("%4t  %b |    %b%b%b       %b%b%b       %b%b%b       %b%b%b   |   %b      %b   |   %2d,%2d        %2d,%2d",
               $time, d, a1,a2,a3, b1,b2,b3, c1,c2,c3, e1,e2,e3, {p[0],p[1],p[2],p[3]}, {r[0],r[1],r[2],r[3]}, sa_nb, sb_nb, sa_b, sb_b);
      @(negedge clk);
    end
    $display("Simulation complete:");
    $finish;
  end
endmodule
