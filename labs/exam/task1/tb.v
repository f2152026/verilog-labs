// tb.v -- Given, do not modify.
// Interface check only: confirms that sensor_vote, parking_lot and occupancy_ctrl
// exist with the ports of Figure A1. It does NOT check that they work.
`timescale 1ns/1ps
module tb;
  reg        a = 0, b = 0, c = 0, clk = 0, rst_n = 0, car_in = 0, car_out = 0, fault_i = 0;
  reg  [5:0] sens = 0;
  wire       m, f, open1, open2, fault1;
  wire [2:0] count1, count2;
  wire [1:0] light1, light2;

  sensor_vote    UV (.a(a), .b(b), .c(c), .m(m), .f(f));
  occupancy_ctrl UO (.clk(clk), .rst_n(rst_n), .car_in(car_in), .car_out(car_out), .fault(fault_i),
                     .count(count1), .open_in(open1), .light(light1));
  parking_lot    UP (.clk(clk), .rst_n(rst_n), .sens(sens),
                     .count(count2), .open_in(open2), .light(light2), .fault(fault1));

  string vcd_file;
  initial begin
    if ($value$plusargs("vcd=%s", vcd_file)) begin
      $dumpfile(vcd_file);
      $dumpvars(0, tb);
    end
  end

  initial begin
    #1 $display("INTERFACE CHECK DONE (compile warnings about ports, if any, must be fixed)");
    $finish;
  end
endmodule
