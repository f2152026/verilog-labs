// edge_detect.v -- Given, buggy. Should give a one-clock pulse every time the button btn goes from 0 to 1.
`timescale 1ns/1ps
module edge_detect(input clk, input btn, output reg pulse);
  reg prev;                   // btn as it was at the previous clock edge
  always @(posedge clk) begin
    prev  = btn;
    pulse = btn & ~prev;
  end
endmodule
