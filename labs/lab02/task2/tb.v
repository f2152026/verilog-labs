module tb;

  // Testbench parameters; change these to test a different configuration.
  localparam TB_WIDTH = 8;
  localparam TB_DEPTH = 8;

  reg  [2:0]          t_sel;   // 3 bits covers DEPTH up to 8
  wire [TB_WIDTH-1:0] t_dout;

  integer i;
  integer errors;

  // Parameter override at instantiation; instance is named DUT to match
  // the $dumpvars call below.
  lut #(.WIDTH(TB_WIDTH), .DEPTH(TB_DEPTH)) DUT (
    .sel  (t_sel),
    .dout (t_dout)
  );

  // Waveform dump configuration (DO NOT CHANGE)
  string vcd_file;
  initial begin
    if ($value$plusargs("vcd=%s", vcd_file)) begin
      $dumpfile(vcd_file);
      $dumpvars(0, DUT);
    end
  end

  initial begin
    errors = 0;
    t_sel  = 0;
    for (i = 0; i < TB_DEPTH; i = i + 1) begin
      t_sel = i;
      #5;                                  // let the combinational read settle
      if (t_dout !== i * i) begin
        $display("MISMATCH at sel=%0d: got %0d, expected %0d",
                 t_sel, t_dout, i * i);
        errors = errors + 1;
      end
    end
    if (errors == 0)
      $display("PASS: all %0d locations read back sel*sel", TB_DEPTH);
    else
      $display("FAIL: %0d mismatches", errors);
    $finish;
  end

  initial
    $monitor($time, " sel=%0d | dout=%0d", t_sel, t_dout);

endmodule