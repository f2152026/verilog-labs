// tb.v -- Given, do not modify.
//
// One clock pulse = one second. Applies 125 pulses to mod60 and checks the count
// just before every falling clock edge (the 7493 counts on the falling edge).
`timescale 1ns/1ps
module tb;
  parameter T = 400;
  reg clk = 1, rst = 0;
  wire [3:0] units;
  wire [2:0] tens;

  mod60 DUT (.clk(clk), .rst(rst), .units(units), .tens(tens));

  string vcd_file;
  initial begin
    if ($value$plusargs("vcd=%s", vcd_file)) begin
      $dumpfile(vcd_file);
      $dumpvars(0, tb);
    end
  end

  // power-on reset for 100 ns, then the clock starts
  initial begin
    #1   rst = 1;
    #99  rst = 0;
    #20  forever #(T/2.0) clk = ~clk;
  end

  integer n, err = 0;
  initial begin
    $timeformat(-9, 0, " ns", 9);
    for (n = 1; n <= 125; n = n + 1) begin
      @(negedge clk);
      #(T - 1);
      if (n % 10 == 0 || n % 60 >= 58 || n % 60 <= 1)
        $display("%t  seconds=%3d | display = %0d%0d", $time, n, tens, units);
      if (units !== n % 10 || tens !== (n / 10) % 6) begin
        err = err + 1;
        $display("%t  WRONG after %0d pulses: display = %0d%0d", $time, n, tens, units);
      end
    end
    if (err == 0) $display("ALL_TASK7_COUNTS_CORRECT");
    $finish;
  end
endmodule
