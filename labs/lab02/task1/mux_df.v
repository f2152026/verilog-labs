module mux_df (
  input       I0,
  input       I1,
  input       S,
  output wire Y        // was: output reg Y
);

  assign Y = S ? I1 : I0;

endmodule