// shift_b_rev.v -- Given. Version C: blocking assignments, statements in reverse order.
`timescale 1ns/1ps
module shift_b_rev(input clk, input d, output reg q1, q2, q3);
  always @(posedge clk) begin
    q3 = q2;
    q2 = q1;
    q1 = d;
  end
endmodule
