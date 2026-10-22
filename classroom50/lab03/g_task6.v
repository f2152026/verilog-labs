// Autograder testbench for lab03 task6: irr_counter must cycle 001 -> 010 -> 101 -> 111 -> 001.
`timescale 1ns/1ps
module tb;
  reg clk = 1;
  reg [2:0] pre_n = 3'b111, clr_n = 3'b111;
  wire [2:0] q;
  irr_counter DUT (.clk(clk), .pre_n(pre_n), .clr_n(clr_n), .q(q));
  reg [2:0] seq [0:3];
  integer k, err = 0;
  initial begin
    seq[0] = 3'b001; seq[1] = 3'b010; seq[2] = 3'b101; seq[3] = 3'b111;
    #10 pre_n = 3'b110; clr_n = 3'b001;    // force 001
    #100 pre_n = 3'b111; clr_n = 3'b111;
    #100;
    if (q !== 3'b001) begin err = err + 1; $display("FAIL: could not force state 001 (q=%b)", q); end
    for (k = 1; k <= 8; k = k + 1) begin
      clk = 0; #200; clk = 1; #200;
      if (q !== seq[k % 4]) begin err = err + 1; $display("FAIL after %0d pulses: q=%b expected %b", k, q, seq[k % 4]); end
    end
    if (err == 0) $display("TASK6_PASSED");
    $finish;
  end
endmodule
