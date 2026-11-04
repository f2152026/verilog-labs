// tb.v -- Part B1: write your self-checking testbench for ticket_machine here.
// Your testbench must end by printing exactly one line:  RESULT: PASS  or  RESULT: FAIL
`timescale 1ns/1ps
module tb;

  // waveform dump for the Run button: keep this block
  string vcd_file;
  initial begin
    if ($value$plusargs("vcd=%s", vcd_file)) begin
      $dumpfile(vcd_file);
      $dumpvars(0, tb);
    end
  end

endmodule
