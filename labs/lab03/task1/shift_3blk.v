// shift_3blk.v -- Given. Version D: blocking assignments, one always block per flip-flop.
`timescale 1ns/1ps
module shift_3blk(input clk, input d, output reg q1, q2, q3);
  always @(posedge clk) q1 = d;
  always @(posedge clk) q2 = q1;
  always @(posedge clk) q3 = q2;
endmodule
