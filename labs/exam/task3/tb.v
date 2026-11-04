// tb.v -- Part B2. Do NOT change the input sequence.
// You may add $display / $monitor statements here and inside ticket_machine.v.
`timescale 1ns/1ps
module tb;
  reg clk = 0, rst_n = 0, c5 = 0, c10 = 0, cancel = 0;
  wire [4:0] credit;
  wire vend;
  ticket_machine dut (.clk(clk), .rst_n(rst_n), .c5(c5), .c10(c10), .cancel(cancel),
              .credit(credit), .vend(vend));
  string vcd_file;
  initial begin
    if ($value$plusargs("vcd=%s", vcd_file)) begin
      $dumpfile(vcd_file);
      $dumpvars(0, tb);
    end
  end

  always #5 clk = ~clk;
  initial begin
    #12 rst_n = 1;
    @(negedge clk) c5 = 1;
    @(negedge clk);
    @(negedge clk);
    @(negedge clk) c5 = 0;
    @(negedge clk) c5 = 1;
    @(negedge clk) c5 = 0; c10 = 1;
    @(negedge clk);
    @(negedge clk) c10 = 0; c5 = 1;
    @(negedge clk) c5 = 0;
    @(negedge clk) c10 = 1;
    @(negedge clk) c10 = 0;
    #1 rst_n = 0;  #2 rst_n = 1;
    @(negedge clk) c5 = 1;
    @(negedge clk) c5 = 0;
    @(negedge clk) $finish;
  end
endmodule
