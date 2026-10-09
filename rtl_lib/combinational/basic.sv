module asynchronous_reset(
  input wire clk,
  input wire reset,
  input wire d,
  output reg q
);

  always_ff @(posedge clk or negedge reset) begin
    if (~reset) begin
      q <= 0;
    end
    else begin
      q <= d;
    end
  end

endmodule


module synchronous_reset(
  input wire rst, // active high synchronous reset
  input wire d,
  input wire clk,
  output reg q
);

  always_ff @(posedge clk) begin
  if (rst)
      q <= 0;
  else
      q <= d;
  end

endmodule

module sync_and_async_reset(
  input wire arst, // active high asynchronous reset
  input wire srst, // active high synchronous reset
  input wire d,
  input wire clk,
  output reg q
);

  always_ff @(posedge clk, posedge arst) begin
  if (arst)
      q <= 0;
  else begin
      if (srst)
          q <= 0;
      else
          q <= d;
  end
  end

endmodule

module mux_4_to_1(
  input wire[3:0] in,
  input wire[1:0] sel,
  output reg out
);

  always_comb begin
  case (sel)
      2'b00: out = in[0];
      2'b01: out = in[1];
      2'b10: out = in[2];
      2'b11: out = in[3];
      default: out = 0;
  endcase
  end
endmodule


module sychronous_counter_4_bit(
  input wire clk,
  input wire rst,
  input wire en,
  output reg[3:0] count
);

  always_ff @(posedge clk) begin
  if (rst)
      count <= 0;
  else if (en)
      count <= count + 4'd1;
  end
endmodule


module sychronous_counter_4_bit_with_overflow_v1(
  input wire clk,
  input wire rst,
  input wire en,
  output reg[3:0] count,
  output wire of
);

  always_ff @(posedge clk) begin
  if (rst) begin
      count <= 0;
  end
  else if (en) begin
      count <= count + 4'd1;
  end
  end

  assign of = en && (count == 4'b1111);

endmodule

module sychronous_counter_4_bit_with_overflow_v2(
  input wire clk,
  input wire rst,
  input wire en,
  output reg[3:0] count,
  output reg of
);

  always_ff @(posedge clk) begin
    if (rst) begin
        count <= 0;
        of <= 0;
    end
    else if (en) begin
        // for non-blocking, all RHS is evaluated first, using values that
        // existed BEFORE the clock edge
        count <= count + 4'd1; // old count + 1
        of <= count == 4'b1111;
    end
  end

endmodule

module moore_machine_sequence_detector(
  input wire clk,
  input wire rst,
  input din, // serial line
  output wire detected // goes high for one full cycle
);
  localparam s0 = 3'b000, s1 = 3'b001, s2 = 3'b010, s3 = 3'b011, s4 = 3'b100;

  reg[2:0] state;
  reg[2:0] next_state;


  always_comb begin
      case(state)
      s0: next_state = (din == 1) ? s1: s0;
      s1: next_state = (din == 1) ? s2: s0;
      s2: next_state = (din == 0) ? s3: s2;
      s3: next_state = (din == 1) ? s4: s0;
      s4: next_state = (din == 0) ? s0: s2;
      default: next_state = state;
      endcase
  end

  always_ff @(posedge clk) begin
      if (rst)
          state <= s0;
      else
          state <= next_state;
  end

  // my idea is that detected will be 1 cycle regardless because state will only be in s4 for one cycle before din changes it out of s4
  assign detected = (state == s4);
endmodule

module mealy_machine_sequence_detector(
  input wire clk,
  input wire rst,
  input din, // serial line
  output wire detected
);
  localparam s0 = 2'b00, s1 = 2'b01, s2 = 2'b10, s3 = 2'b11;

  reg[1:0] state;
  reg[1:0] next_state;


  always_comb begin
      case(state)
      s0: next_state = (din == 1) ? s1: s0;
      s1: next_state = (din == 1) ? s2: s0;
      s2: next_state = (din == 0) ? s3: s2;
      s3: next_state = (din == 1) ? s1: s0;
      default: next_state = state;
      endcase
  end

  always_ff @(posedge clk) begin
      if (rst)
          state <= s0;
      else
          state <= next_state;
  end

  assign detected = (state == s3) & (din == 1);

endmodule


module parameterized_FIFO #(parameter WIDTH=8, DEPTH=8) (
  input clk,
  input rst,
  input wire in,
  input wire [WIDTH-1:0] write_line,
  input wire out,
  output reg [WIDTH-1:0] read_line,
  output wire full, // will drive LEDs
  output wire empty
);

  // unpacked memory
  reg [WIDTH-1:0] memory_array[DEPTH-1:0];
  reg [$clog2(DEPTH)-1:0] read_address;
  reg [$clog2(DEPTH)-1:0] write_address;

  wire [$clog2(DEPTH)-1:0] next_read_address;
  wire [$clog2(DEPTH)-1:0] next_write_address;

  initial begin
    if (DEPTH < 2)
      $fatal(1, "DEPTH must be >= 2");

    if (WIDTH < 1)
      $fatal(1, "WIDTH must be >= 1");
  end

  /* full is when write catches up with read, so write == read
     empty is when read catches up with read, so read == write
     That makes write == read an ambigious condition
     This system sacrifices one slot to disambiguate the condition:
        full will go high when next_write == read
  */
    assign next_read_address = (read_address + 1 == DEPTH) ? 0 : read_address + 1;
    assign next_write_address = (write_address + 1 == DEPTH) ? 0 : write_address + 1;

    assign empty = (read_address == write_address);
    assign full = (next_write_address == read_address);

  always_ff @(posedge clk) begin
    if (rst) begin
      read_address <= 0;
      write_address <= 0;
    end

    else begin

      if (in) begin
        if (!full) begin
          memory_array[write_address] <= write_line;
          write_address <= next_write_address;
        end
      end

      if (out) begin
        if (!empty) begin
          read_line <= memory_array[read_address];
          read_address <= next_read_address;
        end
      end

    end

  end


endmodule


module parameterized_parallel_in_serial_out #(parameter WIDTH = 8) (
  input wire clk,
  input wire rst,
  input wire load,
  input wire shift,
  input wire [WIDTH-1:0] parallel_in,
  output wire serial_out,
  output wire busy
);
  reg [WIDTH-1:0] buffer;
  reg [$clog2(WIDTH + 1)-1:0] bits_need_transfer;

  initial begin
    if (WIDTH < 1)
      $fatal(1, "WIDTH must be >= 1");
  end

  assign busy = (bits_need_transfer != 0);

  always_ff @(posedge clk) begin
    if (rst) begin
      buffer <= 0;
      bits_need_transfer <= 0;
    end
    else begin
      if (load) begin
        buffer <= parallel_in;
        bits_need_transfer <= WIDTH;
      end
      else if (busy && shift) begin
        buffer <= buffer << 1;
        bits_need_transfer <= bits_need_transfer - 1;
      end
    end
  end

  assign serial_out = (busy) ? buffer[WIDTH-1] : 0; // when idle, output should be 0

endmodule


module parameterized_serial_in_parallel_out #(parameter WIDTH = 8) (
  input wire clk,
  input wire rst,
  input wire sample,
  input wire serial_in,
  output reg [WIDTH-1:0] parallel_out,
  output reg valid
);
  reg [WIDTH-1:0] buffer;
  reg [$clog2(WIDTH+1) - 1:0] bits_sampled;

  wire publish_on_next_edge;

  initial begin
    if (WIDTH < 1)
      $fatal(1, "WIDTH must be >= 1");
  end
  // my idea is that bits_sampled will only update on the next edge, so it
  // wont be possible to both load the last bit and publish if
  // we have to wait for the bits_sampled = WIDTH
  // if we raise publish one sample before, it will know to publish on the next cycle along with receiving the last bit
  assign publish_on_next_edge = (bits_sampled == WIDTH - 1 && sample);

  always_ff @(posedge clk) begin
    if (rst) begin
      parallel_out <= 0;
      buffer <= 0;
      bits_sampled <= 0;
      valid <= 0;
    end
    else begin
      if (sample && bits_sampled <= WIDTH) begin
        // MSB first
        // buffer <= { buffer[WIDTH-2:0], serial_in };
        buffer <= buffer << 1;
        buffer[0] <= serial_in;
        bits_sampled <= bits_sampled + 1;
      end

      if (publish_on_next_edge) begin
        // if we did just the buffer, parallel out will see the old buffer (before clock edge)
        // and would then be missing the bit that was also receive on this same edge
        // parallel_out <= { buffer[WIDTH-2:0], serial_in };
        parallel_out <= buffer << 1;
        parallel_out[0] <= serial_in;
        bits_sampled <= 0;
        valid <= 1;
      end
      else valid <= 0;
    end

  end

endmodule

module parameterized_bit_reversal #(parameter BITS = 4)(
  input wire [BITS-1:0] bitfield,
  output logic [BITS-1:0] reversed_bitfield
);
  initial begin
    if (BITS <= 1)
      $fatal(1, "BITS must be >= 1");
  end
  for (genvar i = 0; i < BITS; i++) begin : reverse_bits
    assign reversed_bitfield[i] = bitfield[BITS - 1 - i];
  end
endmodule

module parameterized_priority_encoder #(parameter N = 4) (
  input wire [N-1:0] decoded,
  output logic [$clog2(N)-1:0] encoded,
  output logic valid
);
  always_comb begin
    encoded = 0;
    valid = 0;
    for (int i = 0; i < N; i++) begin
      if (decoded[i]) begin
        encoded = $clog2(N)'(i);
        valid = 1;
      end
    end
  end
endmodule

module parameterized_round_robin_arbiter #(parameter N = 4) (
  input wire clk,
  input wire rst,
  input wire [N-1:0] request,
  input wire accept,
  output logic [N-1:0] grant
);
  reg [$clog2(N)-1:0] priority_search_here_reg;
  logic [$clog2(N)-1:0] priority_search_here;

  wire [N-1:0] area_ahead;
  wire [N-1:0] area_behind;
  wire [$clog2(N)-1:0] found_ahead;
  wire [$clog2(N)-1:0] found_behind;
  wire [1:0] valid;
  logic [$clog2(N)-1:0] grant_index;

    /*
    The standard priority encoder
    Start search is at index 1:
        MSB POS:  5 4 3 2 | 1 0
            Req:  0 1 0 0 | 0 1 -> Grant should be 0 0 0 0 0 1
           Area behind|Area ahead
    */

  assign area_ahead = ((request << N - 1 - priority_search_here_reg) >> N - 1 - priority_search_here_reg);
  // area_behind does not need the same truncation as area_ahead
  // Encoder returns MSB so area_ahead is a don't care if anything in area_behind is high
  // If nothing in area_behind is high, but something in aread_ahead is high, encoder for area_behind will return valid[1] = 1
    // But that's okay because found_behind would be a don't care (since there would be a valid found_ahead)
  // If there is neither found ahead nor found behind, then valid[1] = 0
  assign area_behind = request;
  parameterized_priority_encoder #(.N(N)) pe_ahead (.decoded(area_ahead), .encoded(found_ahead), .valid(valid[0]));
  parameterized_priority_encoder #(.N(N)) pe_behind (.decoded(area_behind), .encoded(found_behind), .valid(valid[1]));

  always_comb begin
    grant = (N)'(0);
    grant_index = 0;
    priority_search_here = priority_search_here_reg;
    grant_index = (valid[0]) ? found_ahead : found_behind;
    grant[grant_index] = (valid[1]) ? 1 : 0;

    // accept can be pending when grant is already determined. in this case, wait for accept to go high before
    // attempting to seek the next grant, or else we might lose the current grant when accept is currently pending at 0
    if (accept && grant != 0) begin
      priority_search_here = (grant_index == 0) ? N - 1 : grant_index - 1;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      priority_search_here_reg <= 0;
    end
    else begin
        priority_search_here_reg <= priority_search_here;
    end
  end

endmodule
