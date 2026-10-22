// skew_shift.v -- YOU write this.
// Two-stage shift register (one IC 7474). Flip-flop 1 is clocked by clk. Flip-flop 2 is clocked by clk delayed through N buffers (IC 7408 gates with both inputs tied together), built with a generate loop.
`timescale 1ns/1ps
module skew_shift #(parameter N = 0) (input clk, input clr_n, input d, output q1, output q2);

  // TODO

endmodule
