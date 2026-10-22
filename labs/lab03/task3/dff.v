// dff.v -- Given, do not modify. D flip-flop, rising edge, asynchronous active-low reset.
`timescale 1ns/1ps
module dff(input clk, input rst_n, input d, output reg q);
  always @(posedge clk or negedge rst_n)
    if (!rst_n) q <= 1'b0;
    else        q <= d;
endmodule
