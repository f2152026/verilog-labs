// next_credit: works out what credit should become at the next clock edge
module next_credit (input [4:0] credit, input c5, c10, cancel, vend,
                    output reg [4:0] next);
  reg [3:0] sum;                       // credit plus the coin inserted in this cycle
  always @(*) begin
    sum = credit + (c5 ? 5'd5 : 5'd0) + (c10 ? 5'd10 : 5'd0);
    if (cancel)    next = 5'd0;        // money returned
    else if (vend) next = sum - 5'd15; // a ticket is paid for in this cycle
    else           next = sum;
  end
endmodule

// credit_reg: stores credit; rst_n clears it
module credit_reg (input clk, rst_n, input [4:0] d, output reg [4:0] q);
  always @(posedge clk)
    if (!rst_n) q <= 5'd0;
    else        q <= d;
endmodule

// vend_check: vend = 1 while credit is enough for a ticket
module vend_check (input [4:0] credit, output vend);
  assign vend = (credit >= 5'd15);
endmodule

// ticket_machine: top level
module ticket_machine (input clk, rst_n, c5, c10, cancel,
                       output [4:0] credit, output vend);
  wire [4:0] next;
  next_credit U1 (credit, c5, c10, cancel, vend, next);
  credit_reg  U2 (clk, rst_n, next, credit);
  vend_check  U3 (credit, vend);
endmodule
