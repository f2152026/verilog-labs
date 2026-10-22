// snippets.v -- Given. Small modules to synthesize in Task 2. Do not modify.
`timescale 1ns/1ps

// ---- (a) the shift registers from Task 1 ----
module sh_nb(input clk, input d, output reg q1, q2, q3);
  always @(posedge clk) begin q1 <= d; q2 <= q1; q3 <= q2; end
endmodule

module sh_b(input clk, input d, output reg q1, q2, q3);
  always @(posedge clk) begin q1 = d; q2 = q1; q3 = q2; end
endmodule

module sh_b_rev(input clk, input d, output reg q1, q2, q3);
  always @(posedge clk) begin q3 = q2; q2 = q1; q1 = d; end
endmodule

// ---- (b) a temporary variable inside a clocked block ----
module tmp_first(input clk, input a, b, c, output reg y);
  reg t;
  always @(posedge clk) begin
    t = a & b;
    y <= t | c;
  end
endmodule

module tmp_last(input clk, input a, b, c, output reg y);
  reg t;
  always @(posedge clk) begin
    y <= t | c;
    t = a & b;
  end
endmodule

// ---- (c) combinational always blocks ----
module comb_if(input en, input d, output reg q);
  always @(*)
    if (en) q = d;
endmodule

module comb_case(input [1:0] sel, input a, b, c, output reg y);
  always @(*)
    case (sel)
      2'b00: y = a;
      2'b01: y = b;
      2'b10: y = c;
    endcase
endmodule

module comb_case_default(input [1:0] sel, input a, b, c, output reg y);
  always @(*)
    case (sel)
      2'b00: y = a;
      2'b01: y = b;
      2'b10: y = c;
      default: y = 1'b0;
    endcase
endmodule

// ---- (d) where does the reset go? ----
module cnt_async(input clk, input rst_n, output reg [3:0] q);
  always @(posedge clk or negedge rst_n)
    if (!rst_n) q <= 4'd0;
    else        q <= q + 4'd1;
endmodule

module cnt_sync(input clk, input rst_n, output reg [3:0] q);
  always @(posedge clk)
    if (!rst_n) q <= 4'd0;
    else        q <= q + 4'd1;
endmodule
