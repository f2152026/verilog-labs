// cla64_flat.v
// A flat, unblocked 64-bit carry-lookahead adder: every carry is computed
// directly (two-level, no rippling), exactly like cla4.v, just scaled to
// 64 bits. Add delays throughout (same convention as cla4.v) so it can be
// fairly compared against rca64.v and cla64_blocked.v.

module cla64_flat(
  input  [63:0] a,
  input  [63:0] b,
  input         cin,
  output [63:0] sum,
  output        cout
);

  wire [63:0] p, g;
  wire [64:1] c;

  genvar i;
  generate
    for (i = 0; i < 64; i = i + 1) begin : gen_pg
      xor #(2) (p[i], a[i], b[i]);
      and #(2) (g[i], a[i], b[i]);
    end
  endgenerate

  genvar k, j;
  generate
    for (k = 1; k <= 64; k = k + 1) begin : gen_carry
      wire [k:0] term;

      assign #(2) term[0] = g[k-1];

      for (j = 1; j < k; j = j + 1) begin : gen_terms
        assign #(2) term[j] = (&p[k-1:k-j]) & g[k-j-1];
      end

      assign #(2) term[k] = (&p[k-1:0]) & cin;

      assign #(2) c[k] = |term;
    end
  endgenerate

  assign cout = c[64];
  assign #(2) sum = p ^ {c[63:1], cin};

endmodule
