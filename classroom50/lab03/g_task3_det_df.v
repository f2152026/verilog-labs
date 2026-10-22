// Autograder testbench for lab03 task3: det_df must detect 0110 (Mealy).
`timescale 1ns/1ps
module tb;
  reg clk = 0, rst_n = 0, x = 1;
  wire y;
  det_df DUT (.clk(clk), .rst_n(rst_n), .x(x), .y(y));
  always #5 clk = ~clk;
  reg [59:0] stream = 60'b0110110_0101010_01110_0100_11_0110_0_0101_11111_0110100101100_00101101;
  reg [3:0] hist = 4'b1111, w;
  reg y_exp_moore = 0;
  integer n, err = 0;
  initial begin
    #12 rst_n = 1;
    for (n = 0; n < 60; n = n + 1) begin
      @(negedge clk) x = stream[59-n];
      #2 w = {hist[2:0], x};
      if (y !== (w == 4'b0110)) begin
        err = err + 1;
        $display("FAIL bit %0d: x=%b y=%b", n, x, y);
      end
      @(posedge clk) hist = w;
      #1 y_exp_moore = (hist == 4'b0110);
    end
    if (err == 0) $display("TASK3A_PASSED");
    $finish;
  end
endmodule
