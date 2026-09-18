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

  wire [63:0] p, g;
  assign #(2) p = a ^ b;
  assign #(2) g = a & b;

  wire [15:0] BP, BG;
  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : gen_BP_BG
      assign #(2) BP[i] = p[i*4+3] & p[i*4+2] & p[i*4+1] & p[i*4];
      assign #(2) BG[i] = g[i*4+3] | 
                          (p[i*4+3] & g[i*4+2]) | 
                          (p[i*4+3] & p[i*4+2] & g[i*4+1]) | 
                          (p[i*4+3] & p[i*4+2] & p[i*4+1] & g[i*4]);
    end
  endgenerate

  wire [3:0] SP, SG;
  generate
    for (i = 0; i < 4; i = i + 1) begin : gen_SP_SG
      assign #(2) SP[i] = BP[i*4+3] & BP[i*4+2] & BP[i*4+1] & BP[i*4];
      assign #(2) SG[i] = BG[i*4+3] | 
                          (BP[i*4+3] & BG[i*4+2]) | 
                          (BP[i*4+3] & BP[i*4+2] & BG[i*4+1]) | 
                          (BP[i*4+3] & BP[i*4+2] & BP[i*4+1] & BG[i*4]);
    end
  endgenerate

  wire [4:0] SC;
  assign SC[0] = cin;
  assign #(2) SC[1] = SG[0] | (SP[0] & SC[0]);
  assign #(2) SC[2] = SG[1] | (SP[1] & SG[0]) | (SP[1] & SP[0] & SC[0]);
  assign #(2) SC[3] = SG[2] | (SP[2] & SG[1]) | (SP[2] & SP[1] & SG[0]) | (SP[2] & SP[1] & SP[0] & SC[0]);
  assign #(2) SC[4] = SG[3] | (SP[3] & SG[2]) | (SP[3] & SP[2] & SG[1]) | (SP[3] & SP[2] & SP[1] & SG[0]) | (SP[3] & SP[2] & SP[1] & SP[0] & SC[0]);
  assign cout = SC[4];

  wire [15:0] BC;
  generate
    for (i = 0; i < 4; i = i + 1) begin : gen_BC
      assign BC[i*4] = SC[i];
      assign #(2) BC[i*4+1] = BG[i*4]   | (BP[i*4]   & SC[i]);
      assign #(2) BC[i*4+2] = BG[i*4+1] | (BP[i*4+1] & BG[i*4]) | (BP[i*4+1] & BP[i*4] & SC[i]);
      assign #(2) BC[i*4+3] = BG[i*4+2] | (BP[i*4+2] & BG[i*4+1]) | (BP[i*4+2] & BP[i*4+1] & BG[i*4]) | (BP[i*4+2] & BP[i*4+1] & BP[i*4] & SC[i]);
    end
  endgenerate

  generate
    for (i = 0; i < 16; i = i + 1) begin : gen_cla4
      cla4 block (
        .a(a[i*4+3 : i*4]),
        .b(b[i*4+3 : i*4]),
        .cin(BC[i]),              
        .sum(sum[i*4+3 : i*4]),
        .cout()                    
      );
    end
  endgenerate

endmodule