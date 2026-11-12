# F215 Verilog: Syntax Sheet

*Syntax only. Compile with `iverilog -g2012`. Every snippet on this sheet compiles.*

## 1. Module, ports, declarations

```verilog
module name (
  input        a, b,        // 1-bit
  input  [3:0] d,           // 4-bit vector, d[3] is MSB
  input        clk, rst_n,
  output       y,           // driven by assign / instance
  output reg [1:0] q        // driven by always
);
  wire       w1, w2;        // internal nets
  wire [7:0] bus;
  reg  [2:0] s;             // assigned inside always
  // ... statements ...
endmodule
```

*wire: driven by assign, a gate or an instance output.  reg: assigned inside always/initial.*

## 2. Numbers and vectors

```verilog
4'b1010   4'd10   4'hA   1'b0   1'b1   8'b0000_1111
d[2]         // one bit
d[3:1]       // slice (3 bits)
{a, b, d}    // concatenation: 6 bits, a is MSB
{4{1'b0}}    // replication: 4'b0000
```

## 3. Gate primitives

```verilog
and  g1 (y, a, b);       // OUTPUT FIRST, then inputs
or   g2 (w1, a, b, c);    // any number of inputs
not  g3 (w2, a);
nand (w3, a, b);          // instance name optional
// also: nor  xor  xnor  buf
```

## 4. Instantiating a module

```verilog
// named ports (recommended):  .port(signal)
half_add U1 (.x(a), .y(b), .s(w1), .c(w2));
half_add U2 (.x(w1), .y(cin), .s(sum), .c(w3));
// connect a slice or a concatenation:
blk U3 (.in({a, d[1:0]}), .out(bus[2:0]));
// positional (order must match the module header):
half_add U4 (a, b, w1, w2);
```

## 5. Dataflow (assign)

```verilog
assign y   = (a & b) | ~c;
assign w   = sel ? d1 : d0;      // 2:1 mux
assign sum = d + 4'd1;
assign eq  = (d == 4'b0101);
```

| Kind | Operators |
|---|---|
| Bitwise | `~  &  \|  ^  ~^` |
| Logical | `!  &&  \|\|` |
| Reduction | `&d  \|d  ^d   (all bits -> 1 bit)` |
| Compare | `==  !=  <  >  <=  >=   ===  !==  (match x/z too)` |
| Arithmetic | `+  -  *` |
| Shift | `<<  >>` |
| Conditional | `c ? t : f` |

## 6. Behavioural (always)

```verilog
// combinational: use =
always @(*) begin
  if (a)        y = 1'b1;
  else if (b)   y = c;
  else          y = 1'b0;
end

always @(*) begin
  case (sel)
    2'b00:   z = d[0];
    2'b01:   z = d[1];
    default: z = 1'b0;
  endcase
end

// clocked: use <=
always @(posedge clk)                  // synchronous
  q <= next_q;

// asynchronous, active-low reset
always @(posedge clk or negedge rst_n)
  if (!rst_n) q <= 2'b00;
  else        q <= next_q;

localparam S0 = 2'd0, S1 = 2'd1;       // named constants
```

*More than one statement in an if/else branch, a case item or an always block needs begin ... end.*

## 7. Testbench

```verilog
`timescale 1ns/1ps
module tb;
  reg        a, clk = 0, rst_n;   // DUT inputs: reg
  reg  [3:0] d;
  wire       y;                   // DUT outputs: wire
  integer    i, errors = 0;

  name dut (.a(a), .d(d), .clk(clk), .rst_n(rst_n), .y(y));

  always #5 clk = ~clk;           // period 10

  initial begin
    rst_n = 0;  a = 0;  d = 4'd0;
    #12 rst_n = 1;
    for (i = 0; i < 16; i = i + 1) begin
      @(negedge clk);             // wait for a clock edge
      d = i;
      #1;                         // wait 1 time unit
      if (y !== 1'b0) begin
        $display("t=%0t d=%b y=%b", $time, d, y);
        errors = errors + 1;
      end
    end
    $display("errors = %0d", errors);
    $finish;
  end
endmodule
```

```verilog
// waveform dump (needed for the Run button)
string vcd_file;
initial if ($value$plusargs("vcd=%s", vcd_file)) begin
  $dumpfile(vcd_file);  $dumpvars(0, tb);
end
```

| Item | Meaning |
|---|---|
| `$display(...)` | print once, with newline |
| `$write(...)` | print once, no newline |
| `$monitor(...)` | print whenever an argument changes |
| `$time` | current simulation time |
| `$finish` | end the simulation |
| `%b %d %h %0d %t %0t` | binary, decimal, hex, no padding, time |

## 8. iverilog messages

| Message | Usually means |
|---|---|
| syntax error  (line N) | Often a missing ; on line N-1, or a missing end / endcase / endmodule |
| x is not a valid l-value ... declared here as wire | x is assigned in always: declare it reg |
| Unable to bind wire/reg/memory \`x' | x is used but never declared (spelling?) |
| port \`\`x'' is not a port of U1 | wrong port name in .x(...) |
| Unknown module type: foo | module name misspelt, or its file is missing |
| x has already been declared | declared twice (e.g. in port list and again inside) |
| warning: implicit definition of wire 'x' | undeclared signal in an instance: it became a 1-bit wire |
| warning: Port 1 (a) of c expects 4 bits, got 2 | width of the connected signal is wrong |
