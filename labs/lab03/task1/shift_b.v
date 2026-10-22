// shift_b.v -- Given. Version B: blocking assignments in one always block.
`timescale 1ns/1ps
module shift_b(input clk, input d, output reg q1, q2, q3);
  always @(posedge clk) begin
    q1 = d;
    q2 = q1;
    q3 = q2;
  end
endmodule
