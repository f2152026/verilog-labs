// swap.v -- Given. Two registers that load on load=1 and exchange contents on load=0.
`timescale 1ns/1ps
module swap_nb(input clk, input load, input [3:0] ain, bin, output reg [3:0] a, b);
  always @(posedge clk)
    if (load) begin a <= ain; b <= bin; end
    else      begin a <= b;   b <= a;   end
endmodule

module swap_b(input clk, input load, input [3:0] ain, bin, output reg [3:0] a, b);
  always @(posedge clk)
    if (load) begin a = ain; b = bin; end
    else      begin a = b;   b = a;   end
endmodule
