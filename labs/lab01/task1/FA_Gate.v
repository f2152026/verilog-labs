// FA_Gate.v
// Gate-level model of a 1-bit full adder. No delays yet -- that starts in
// Task 2. This task is purely about gate ordering.
//
// Part (a): leave this file exactly as it is, compile, and simulate.
// Part (b): AFTER completing part (a), come back and reorder the five gate
//           instantiations below into any different sequence, then
//           re-simulate with the same tb.v and compare.

module FA_Gate(
  input  a,
  input  b,
  input  cin,
  output sum,
  output cout
);
  wire ps, pc1, pc2;

  or  (cout, pc1, pc2); 
  and (pc2, cin, ps);
  xor (sum, cin, ps);
  and (pc1, a,   b);
  xor (ps,  a,   b);   

  xor #(2) (ps,  a,   b);
  and #(2) (pc1, a,   b);
  xor #(2) (sum, cin, ps);
  and #(2) (pc2, cin, ps);
  or  #(2) (cout, pc1, pc2);

endmodule
