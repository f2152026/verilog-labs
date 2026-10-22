// tb.v -- Given, do not modify (except the clock period T in part (d)).
//
// Drives counter16 and bcd_counter from the same clock. The 7493 counts on the
// FALLING edge of its clock. Just before every falling edge the testbench reads
// both counts and checks them; that is the moment a circuit using the count
// would look at it.
`timescale 1ns/1ps
module tb;
  parameter T = 400;          // clock period in ns  <-- change this in part (d)

  reg clk = 1, rst = 0;
  wire [3:0] q16, qbcd;

  counter16   U16  (.clk(clk), .rst(rst), .q(q16));
  bcd_counter UBCD (.clk(clk), .rst(rst), .q(qbcd));

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

  integer n, err16 = 0, errbcd = 0;
  initial begin
    $timeformat(-9, 0, " ns", 9);
    for (n = 1; n <= 20; n = n + 1) begin
      @(negedge clk);                       // the counter counts here ...
      #(T - 1);                             // ... and is read 1 ns before the next count edge
      $display("%t  pulses=%2d | counter16 = %b (%2d) | bcd_counter = %b (%0d)",
               $time, n, q16, q16, qbcd, qbcd);
      if (q16  !== n % 16) err16  = err16  + 1;
      if (qbcd !== n % 10) errbcd = errbcd + 1;
    end
    if (err16 == 0 && errbcd == 0) $display("ALL_TASK4_COUNTS_CORRECT (T = %0d ns)", T);
    else $display("WRONG COUNTS at T = %0d ns: counter16 %0d, bcd_counter %0d", T, err16, errbcd);
    $finish;
  end
endmodule
