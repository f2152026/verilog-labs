// chips.v -- 74xx chip models WITH PROPAGATION DELAYS (Lab 3).
// Given -- do not modify. Use these modules exactly as given.
//
// Active-low pins end in _n. Unused inputs must still be tied to 1'b0 or 1'b1.
// All flip-flops power up in an unknown state (x): clear or preset them first.
//
// Timing (all in ns, same for every gate/flip-flop of a type):
//   gates 7400 7402 7404 7408 7410 7432 7486 : tpd  = 10  (input change -> output)
//   7474 (D flip-flop, rising edge)          : tpcq = 20  (clock edge -> Q)
//   74112 (JK flip-flop, falling edge)       :        tsu = 15, th = 5
//                                              PRE_n/CLR_n -> Q = 20
//   7493 (ripple counter)                    : each internal stage 15 (its clock edge -> its Q)
//                                              R01=R02=1 -> all outputs 0 after 20
//
// A flip-flop whose D (or J/K) input changes less than tsu before, or less than th
// after, its active clock edge cannot decide: its Q becomes x and a message is printed.
`timescale 1ns/1ps

module ic7400(input A1,B1,A2,B2,A3,B3,A4,B4, output Y1,Y2,Y3,Y4); // quad 2-input NAND
  assign #10 Y1=~(A1&B1); assign #10 Y2=~(A2&B2); assign #10 Y3=~(A3&B3); assign #10 Y4=~(A4&B4);
endmodule
module ic7402(input A1,B1,A2,B2,A3,B3,A4,B4, output Y1,Y2,Y3,Y4); // quad 2-input NOR
  assign #10 Y1=~(A1|B1); assign #10 Y2=~(A2|B2); assign #10 Y3=~(A3|B3); assign #10 Y4=~(A4|B4);
endmodule
module ic7404(input A1,A2,A3,A4,A5,A6, output Y1,Y2,Y3,Y4,Y5,Y6); // hex inverter
  assign #10 Y1=~A1; assign #10 Y2=~A2; assign #10 Y3=~A3;
  assign #10 Y4=~A4; assign #10 Y5=~A5; assign #10 Y6=~A6;
endmodule
module ic7408(input A1,B1,A2,B2,A3,B3,A4,B4, output Y1,Y2,Y3,Y4); // quad 2-input AND
  assign #10 Y1=A1&B1; assign #10 Y2=A2&B2; assign #10 Y3=A3&B3; assign #10 Y4=A4&B4;
endmodule
module ic7410(input A1,B1,C1,A2,B2,C2,A3,B3,C3, output Y1,Y2,Y3); // triple 3-input NAND
  assign #10 Y1=~(A1&B1&C1); assign #10 Y2=~(A2&B2&C2); assign #10 Y3=~(A3&B3&C3);
endmodule
module ic7432(input A1,B1,A2,B2,A3,B3,A4,B4, output Y1,Y2,Y3,Y4); // quad 2-input OR
  assign #10 Y1=A1|B1; assign #10 Y2=A2|B2; assign #10 Y3=A3|B3; assign #10 Y4=A4|B4;
endmodule
module ic7486(input A1,B1,A2,B2,A3,B3,A4,B4, output Y1,Y2,Y3,Y4); // quad 2-input XOR
  assign #10 Y1=A1^B1; assign #10 Y2=A2^B2; assign #10 Y3=A3^B3; assign #10 Y4=A4^B4;
endmodule

// dual D flip-flop, rising edge, async active-low preset and clear (do not assert both)
module ic7474(input D1,CLK1,PRE1_n,CLR1_n, D2,CLK2,PRE2_n,CLR2_n, output Q1,Q1_n,Q2,Q2_n);
  ff_core #(.JK(0), .FALLING(0)) ff1 (.D(D1), .J(1'b0), .K(1'b0), .CLK(CLK1), .PRE_n(PRE1_n), .CLR_n(CLR1_n), .Q(Q1), .Q_n(Q1_n));
  ff_core #(.JK(0), .FALLING(0)) ff2 (.D(D2), .J(1'b0), .K(1'b0), .CLK(CLK2), .PRE_n(PRE2_n), .CLR_n(CLR2_n), .Q(Q2), .Q_n(Q2_n));
endmodule

// dual JK flip-flop, falling edge, async active-low preset and clear (do not assert both)
module ic74112(input J1,K1,CLK1,PRE1_n,CLR1_n, J2,K2,CLK2,PRE2_n,CLR2_n, output Q1,Q1_n,Q2,Q2_n);
  ff_core #(.JK(1), .FALLING(1)) ff1 (.D(1'b0), .J(J1), .K(K1), .CLK(CLK1), .PRE_n(PRE1_n), .CLR_n(CLR1_n), .Q(Q1), .Q_n(Q1_n));
  ff_core #(.JK(1), .FALLING(1)) ff2 (.D(1'b0), .J(J2), .K(K2), .CLK(CLK2), .PRE_n(PRE2_n), .CLR_n(CLR2_n), .Q(Q2), .Q_n(Q2_n));
endmodule

// 4-bit ripple counter. QA toggles on CKA_n falling edge; QB..QD count on CKB_n falling edge
// (QB toggles when CKB_n falls, QC when QB falls, QD when QC falls).
// Wire QA to CKB_n for a 0-15 counter. Async reset when R01 and R02 are both 1.
module ic7493(input CKA_n,CKB_n,R01,R02, output QA,QB,QC,QD);
  reg qa = 1'bx, qb = 1'bx, qc = 1'bx, qd = 1'bx;
  wire r = R01 & R02;
  always @(negedge CKA_n or posedge r) if (r) qa <= #20 1'b0; else qa <= #15 ~qa;
  always @(negedge CKB_n or posedge r) if (r) qb <= #20 1'b0; else qb <= #15 ~qb;
  always @(negedge qb    or posedge r) if (r) qc <= #20 1'b0; else qc <= #15 ~qc;
  always @(negedge qc    or posedge r) if (r) qd <= #20 1'b0; else qd <= #15 ~qd;
  assign QA = qa; assign QB = qb; assign QC = qc; assign QD = qd;
endmodule

// ---------------------------------------------------------------------------------------
// One flip-flop with timing checks (used inside ic7474 and ic74112; do not use directly).
module ff_core #(parameter JK = 0, FALLING = 0, TPCQ = 20, TSU = 15, TH = 5, TPRE = 20)
                (input D, J, K, CLK, PRE_n, CLR_n, output Q, Q_n);
  reg  q = 1'bx;
  time t_in = 0, t_edge = 0;
  reg  seen_edge = 0;
  wire active = FALLING ? ~CLK : CLK;
  wire din    = JK ? ((J & ~q) | (~K & q)) : D;

  // data input changed: remember when, and check the hold window of the last edge
  always @(D or J or K) begin
    if (seen_edge && PRE_n === 1'b1 && CLR_n === 1'b1 && ($time - t_edge) < TH) begin
      $display("%0d ns: %m HOLD violation: input changed %0d ns after the clock edge (th = %0d ns)",
               $time, $time - t_edge, TH);
      q <= #(TPCQ - ($time - t_edge)) 1'bx;
    end
    t_in = $time;
  end

  // active clock edge: check the setup window, then capture
  always @(posedge active) begin
    t_edge = $time; seen_edge = 1;
    if (PRE_n === 1'b1 && CLR_n === 1'b1) begin
      if ($time > 0 && ($time - t_in) < TSU) begin
        $display("%0d ns: %m SETUP violation: input changed %0d ns before the clock edge (tsu = %0d ns)",
                 $time, $time - t_in, TSU);
        q <= #TPCQ 1'bx;
      end else
        q <= #TPCQ din;
    end
  end

  // asynchronous preset / clear (clear wins if both are asserted)
  always @(CLR_n or PRE_n)
    if (CLR_n === 1'b0) q <= #TPRE 1'b0; else if (PRE_n === 1'b0) q <= #TPRE 1'b1;

  assign Q = q; assign Q_n = ~q;
endmodule
