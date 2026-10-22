// tb.v -- Given, do not modify.
// Checks edge_detect and prio_enc against their specifications.
`timescale 1ns/1ps
module tb;
  reg clk = 0, btn = 0;
  reg [3:0] r;                 // starts at x, so the first value applied is a change
  wire pulse, valid;
  wire [1:0] y;

  edge_detect UE (.clk(clk), .btn(btn), .pulse(pulse));
  prio_enc    UP (.r(r), .y(y), .valid(valid));

  string vcd_file;
  initial begin
    if ($value$plusargs("vcd=%s", vcd_file)) begin
      $dumpfile(vcd_file);
      $dumpvars(0, tb);
    end
  end

  always #5 clk = ~clk;

  // ---- edge_detect: btn is held for several clocks at a time ----
  reg [15:0] press = 16'b0011_1100_0111_0010;   // btn value for 16 clock cycles, MSB first
  reg prev_btn = 0, exp_pulse;
  integer n, err_e = 0, err_p = 0, i;
  initial begin
    for (n = 0; n < 16; n = n + 1) begin
      @(negedge clk) btn = press[15-n];
      @(posedge clk) begin exp_pulse = btn & ~prev_btn; prev_btn = btn; end
      #1;
      $display("cycle %2d  btn=%b  pulse=%b  (expected %b)", n, btn, pulse, exp_pulse);
      if (pulse !== exp_pulse) err_e = err_e + 1;
    end
  end

  // ---- prio_enc: every input value, in an order that returns to 0000 often ----
  reg [1:0] exp_y; reg exp_v;
  initial begin
    #3;
    for (i = 0; i < 32; i = i + 1) begin
      r = (i % 2) ? i[4:1] : 4'b0000;
      #2;
      exp_v = |r;
      exp_y = r[3] ? 2'd3 : r[2] ? 2'd2 : r[1] ? 2'd1 : 2'd0;
      if (y !== exp_y || valid !== exp_v) begin
        $display("prio_enc FAIL: r=%b  got y=%d valid=%b  expected y=%d valid=%b", r, y, valid, exp_y, exp_v);
        err_p = err_p + 1;
      end
    end
  end

  initial begin
    #200;
    if (err_e == 0) $display("EDGE_DETECT_PASSED"); else $display("edge_detect: %0d wrong cycles", err_e);
    if (err_p == 0) $display("PRIO_ENC_PASSED");    else $display("prio_enc: %0d wrong inputs", err_p);
    $finish;
  end
endmodule
