// irr_counter.v -- YOU write this.
// Counter 001 -> 010 -> 101 -> 111 -> 001 ... (q = Q2 Q1 Q0) from IC 74112 JK flip-flops (+ gates if needed). pre_n[i] / clr_n[i] go straight to PRE_n / CLR_n of the flip-flop that drives q[i].
`timescale 1ns/1ps
module irr_counter(input clk, input [2:0] pre_n, input [2:0] clr_n, output [2:0] q);

  // TODO

endmodule
