// cla64_hier.v
// BONUS -- open-ended. No detailed scaffold is provided; this is meant to
// be a genuine design exercise. Not required for lab submission.
//
// You will likely need to modify cla4.v (or add signals alongside it) so
// that block-generate/block-propagate summaries of its own Gi, Pi signals
// are exposed as outputs, since the second-level lookahead unit below
// needs them. As with every module in this lab from Task 2 onward, every
// gate/assign you add should carry an explicit delay.
//
// Starting point (from Tutorial 3, Q4(d)):
//   - Reuse 16 four-bit CLA blocks (your cla4.v) -- their internal logic
//     doesn't change.
//   - For each block k, define:
//       Gblk_k = "this block produces a carry regardless of its incoming
//                 carry" -- a Boolean function of that block's own 4
//                 bit-level Gi, Pi signals.
//       Pblk_k = "an incoming carry sails straight through this whole
//                 block" -- likewise a function of its own Gi, Pi.
//   - Build a second-level lookahead unit -- structurally identical to
//     cla4.v, just one level up -- that computes each block's carry-in
//     directly from Gblk_0..Gblk_15, Pblk_0..Pblk_15, and cin, instead of
//     rippling block to block.
//
// To test this, wire it into dut.v as a fourth option (copy the pattern
// used for the other three) and run it through the same tb.v. Compare
// your final delay to cla64_blocked.v from Task 4.

module cla64_hier(
  input  [63:0] a,
  input  [63:0] b,
  input         cin,
  output [63:0] sum,
  output        cout
);

  wire [15:0] Gblk, Pblk;
  wire [16:0] C;        // C[0]=cin, C[k]=carry into block k, C[16]=cout

  assign C[0] = cin;

  genvar k;
  generate
    for (k = 0; k < 16; k = k + 1) begin : gen_blocks
      cla4 BLK (
        .a    (a[4*k+3 : 4*k]),
        .b    (b[4*k+3 : 4*k]),
        .cin  (C[k]),
        .sum  (sum[4*k+3 : 4*k]),
        .cout (),
        .Gblk (Gblk[k]),
        .Pblk (Pblk[k])
      );
    end
  endgenerate

  genvar m, j;
  generate
    for (m = 1; m <= 16; m = m + 1) begin : gen_C
      wire [m:0] term;

      assign #(2) term[0] = Gblk[m-1];

      for (j = 1; j < m; j = j + 1) begin : gen_terms
        assign #(2) term[j] = (&Pblk[m-1 : m-j]) & Gblk[m-j-1];
      end

      assign #(2) term[m] = (&Pblk[m-1:0]) & cin;

      assign #(2) C[m] = |term;
    end
  endgenerate

  assign cout = C[16];

endmodule