// prio_enc.v -- Given, buggy. 4-input priority encoder: y = index of the highest request line that is 1.
// valid = 1 when at least one request is 1. With no request: y = 0, valid = 0.
`timescale 1ns/1ps
module prio_enc(input [3:0] r, output reg [1:0] y, output reg valid);
  always @(*) begin
    if      (r[3]) begin y = 2'd3; valid = 1'b1; end
    else if (r[2]) begin y = 2'd2; valid = 1'b1; end
    else if (r[1]) begin y = 2'd1; valid = 1'b1; end
    else if (r[0]) begin y = 2'd0; valid = 1'b1; end
  end
endmodule
