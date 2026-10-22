// Autograder testbench for lab03 task1 (shift4_nb, shift4_b).
`timescale 1ns/1ps
module tb;
  reg clk = 0, d = 0;
  wire [3:0] p, r;
  reg  [3:0] ref_q;
  shift4_nb UP (.clk(clk), .d(d), .q(p));
  shift4_b  UR (.clk(clk), .d(d), .q(r));
  always #5 clk = ~clk;
  reg [19:0] pattern = 20'b1011_0010_1110_0110_1001;
  integer n, err = 0;
  initial begin
    for (n = 0; n < 20; n = n + 1) begin
      @(negedge clk) d = pattern[19-n];
      @(posedge clk) ref_q = {ref_q[2:0], d};
      #1;
      if (n >= 4 && (p !== ref_q || r !== ref_q)) begin
        err = err + 1;
        $display("FAIL cycle %0d: expected q=%b, shift4_nb=%b, shift4_b=%b", n, ref_q, p, r);
      end
    end
    if (err == 0) $display("TASK1_PASSED");
    $finish;
  end
endmodule
