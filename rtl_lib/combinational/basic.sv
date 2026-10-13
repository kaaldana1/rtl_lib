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


module FIFO #(parameter int WIDTH=8, parameter int DEPTH=8) (
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


module parallel_in_serial_out #(parameter int WIDTH = 8) (
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


module serial_in_parallel_out #(parameter int WIDTH = 8) (
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

module bit_reversal #(parameter int BITS = 4)(
  input wire [BITS-1:0] bitfield,
  output logic [BITS-1:0] reversed_bitfield
);
  initial begin
    if (BITS <= 1)
      $fatal(1, "BITS must be >= 1");
  end
  for (genvar i = 0; i < BITS; i++) begin : g_reverse_bits
    assign reversed_bitfield[i] = bitfield[BITS - 1 - i];
  end
endmodule

module priority_encoder #(parameter int N = 4) (
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

module round_robin_arbiter #(parameter int N = 4) (
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
  priority_encoder #(.N(N)) pe_ahead (.decoded(area_ahead), .encoded(found_ahead), .valid(valid[0]));
  priority_encoder #(.N(N)) pe_behind (.decoded(area_behind), .encoded(found_behind), .valid(valid[1]));

  always_comb begin
    grant = (N)'(0);
    grant_index = 0;
    priority_search_here = priority_search_here_reg;
    grant_index = (valid[0]) ? found_ahead : found_behind;
    grant[grant_index] = (valid[1]) ? 1 : 0;

    // accept can be pending when grant is already determined. in this case, wait for accept to go high before
    // attempting to seek the next grant, or else we might lose the current grant when accept is currently pending at 0
    if (accept && grant != 0) begin
      priority_search_here = (grant_index == 0) ? ($clog2(N))'(N - 1) : grant_index - 1;
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

module practice_operators #(parameter int WIDTH = 8, parameter int NEW_WIDTH = 16,
                            parameter int W = 8, parameter int V = 16) (
    input wire signed [WIDTH-1:0] a,
    input wire [W-1:0] x,
    input wire [V-1:0] y,
    output logic signed [NEW_WIDTH-1:0] out_1,
    output logic signed [(W*3)-1:0] out_2,
    output wire out_3
);
    logic [W-1:0] all_ones;
    logic [2*W-1:0] pad;
    always_comb begin
      // Drill 1: Write a module that takes input wire signed [7:0] a
      // and produces output wire signed [15:0] y equal to a sign-extended,
      // using concatenation and replication explicitly (don’t just write y = a).
      // Then answer: if a were declared unsigned, would assign y = a;
      // still zero-extend or sign-extend, and why?
        // My answer: It would zero-extend
      out_1 = {{(NEW_WIDTH - WIDTH){a[WIDTH-1]}}, a};

      // Drill 2: Write a module with parameter W = 8 that outputs all_ones
      // (W bits, all 1s) and pad (2*W bits, with the input x in the lower
      // half and zeros above), using only replication and concatenation.
      all_ones = {W{1'b1}};
      pad = {{W{1'b0}}, W'(x)};
      out_2 = {all_ones, pad};
  end

      // Drill 3: Write a one-line assign that outputs 1 only when a
      // 16-bit input is all zeros, using a reduction operator rather than == 0.
      assign out_3 = ~|y;
endmodule


module ReLU #(parameter int WIDTH = 16) (
    input wire signed [WIDTH-1:0] x,
    output wire signed [WIDTH-1:0] y
);
    initial begin
      if (WIDTH < 1)
        $fatal(1, "WIDTH must be at least 1");
    end
    // i believe checking the MSB directly is cheaper than a signed comparison
    // This would just be a mux, with x[WIDTH-1] as the selector
    assign y = (x[WIDTH-1]) ? '0 : x;
endmodule

// output width =  width + [log2(Input count)],
// since each W-bit signed number requires an output width of at
// least W + 1 bits to prevent overflow
module signed_adder_tree #(parameter int WIDTH = 8, parameter int INPUT_COUNT = 4) (
  input wire signed [WIDTH-1:0] in [INPUT_COUNT-1:0],
  output wire signed [(WIDTH + $clog2(INPUT_COUNT)-1):0] out
);
  localparam int STAGES = $clog2(INPUT_COUNT);
  localparam int MAX_NODES = 1 << STAGES;

  // array of wires
  // Each node gets the final max width insitead of declaring each level progressively wider
  // STAGES + 1 stages,
    // each containing MAX_NODES values,
    //   where each value is WIDTH + STAGES bits wide
  wire signed [(WIDTH+STAGES-1):0] tree_stage [STAGES:0][MAX_NODES-1:0];

    for (genvar i = 0; i < MAX_NODES; i++) begin : g_input_stage
      if (i < INPUT_COUNT) begin
        assign tree_stage[0][i] = in[i]; // sign extend data to node width
      end
      else begin
        // handles any non power of two input counts by zeroing out the extra nodes,
        // which will be added to the sum
        assign tree_stage[0][i] = '0;
      end
    end

  // inner loop accounts for number of additions at each stage
  // Since each stage pairs its inputs, it produces half as many outputs.
  // each inner iteration creates on sum
  for (genvar stage = 0; stage < STAGES; stage++) begin : g_adder_tree
    for (genvar node = 0; node < MAX_NODES >> (stage + 1); node++) begin : g_adder_nodes
      assign tree_stage[stage + 1][node] = tree_stage[stage][node * 2] + tree_stage[stage][node * 2 + 1];
    end
  end

  assign out = tree_stage[STAGES][0];
endmodule


module MAC_array #(parameter int WIDTH = 8,
                   parameter int OUTPUT_PARALLEL_LANES = 4,
                   parameter int REDUCTION_PARALLEL_LANES = 4,
                   parameter int INPUT_COUNT = 784,
                   parameter int FINAL_CYCLE = (INPUT_COUNT + REDUCTION_PARALLEL_LANES - 1) / REDUCTION_PARALLEL_LANES
                   )
(
  input wire clk,
  input wire rst,
  // x_input can be shared or otherwise, it should be decided by the caller. Caller provides inputs per cycle
  input wire signed [WIDTH-1:0] one_cycle_operand_1 [OUTPUT_PARALLEL_LANES-1:0][REDUCTION_PARALLEL_LANES-1:0],
  input wire signed [WIDTH-1:0] one_cycle_operand_2 [OUTPUT_PARALLEL_LANES-1:0][REDUCTION_PARALLEL_LANES-1:0],
  output reg signed [2*WIDTH-1:0] accumulate [OUTPUT_PARALLEL_LANES-1:0],
  output reg [$clog2(FINAL_CYCLE)-1:0] cycles,
  output wire complete
);


  logic signed [2*WIDTH-1:0] one_cycle_accumulate_out [OUTPUT_PARALLEL_LANES-1:0][REDUCTION_PARALLEL_LANES-1:0];
  wire signed [2*WIDTH-1:0] one_cycle_adder_out [OUTPUT_PARALLEL_LANES-1:0];


  always_comb begin
    for (int output_lane = 0; output_lane < OUTPUT_PARALLEL_LANES; output_lane++) begin
      for (int reduction = 0; reduction < REDUCTION_PARALLEL_LANES; reduction++) begin
        one_cycle_accumulate_out[output_lane][reduction] = (one_cycle_operand_1[output_lane][reduction]
                                                          * one_cycle_operand_2[output_lane][reduction]);
      end
    end
  end
    // one_cycle_accumuate_out[i][j] -> xiwi
    // one_cycle_accumuate_out[i] -> [xiwi, xi+1*wi+1, xi+2*wi+2, xi+3*wi+3]
                                //-> signed_adder_tree -> xnwn
  for (genvar output_lane = 0; output_lane < OUTPUT_PARALLEL_LANES; output_lane++) begin : g_adder_tree
    signed_adder_tree #(.WIDTH(2*WIDTH), .INPUT_COUNT(REDUCTION_PARALLEL_LANES))
                      add (.in(one_cycle_accumulate_out[output_lane]), .out(one_cycle_adder_out[output_lane]));
    // adder tree output would be 2*WIDTH + log2(REDUCTION_PARALLEL_LANES) bits wide
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      cycles <= 0;
      accumulate <= '{default: '0};
    end
    else begin
      if (cycles < FINAL_CYCLE) begin
        cycles <= cycles + 1;
        for (int i = 0; i < OUTPUT_PARALLEL_LANES; i++)
            accumulate[i] <= accumulate[i] + one_cycle_adder_out[i];
      end
    end
  end

  assign complete = (cycles >= FINAL_CYCLE) ? 1 : 0;
endmodule

/*
data feeder ---inputs, weights, biases--> dense layer----|
                                               |         |
                                            biases   inputs,weights
                                               |         |
                                               |         |     Mac array
                                               |         |---> output lane 0
                                               |         |---> output lane 1
                                               |         |---> output lane 2
                                               |_________|---> output lane 3
                                               |  accumulate complete
                                               V
                                            neuron -> intermediate value -> ReLU -> output
*/

module Neuron #(parameter int WIDTH = 8,
                parameter int ACCUMULATOR_WIDTH = 8)
(
  input wire signed [WIDTH-1:0] bias, // should bias keep to the same size as everything else?
  input wire signed [ACCUMULATOR_WIDTH-1:0] accumulate,
  output wire signed [WIDTH-1:0] activate
);
    wire signed [ACCUMULATOR_WIDTH-1:0] intermediate_value;
    assign intermediate_value = accumulate + bias;
    ReLU #(.WIDTH(WIDTH)) activation_function (.x(intermediate_value), .y(activate));
endmodule

// The dense layer will instantiate the MACS.
// typically id like a shared MAC array and a scheduling system for when several hidden layers
// are involved, but for now a simpler design for a single hidden layer will do

// 782 input x 128 neurons = 100352 MAC operations
// If 20 MACs are instantiated, I think an optimal config is:
  // 4 MACs that do work across inputs (eg MAC_1 does x0 * w0, MAC_2 does x1 * w1 etc...)
    // less serial work for the actual linear expression, so shorter cycles per neuron
  // That gives us max of 5 processing streams
    // More neurons done in parallel
  // A group would have 5 neurons and will need ceil(784/4) = 196 cycles to finish
  // There are 26 groups, so in total 5096 cycles for the entire hidden layer

// If we gave all 20 MACs one neuron at a time, that is 40 cycles to complete a neuron
// But 128 neurons finished sequentually would take 128 * 40 = 5120 cycles

module dense_layer #(parameter int WIDTH = 8,
                   parameter int OUTPUT_PARALLEL_LANES = 4,
                   parameter int REDUCTION_PARALLEL_LANES = 4,
                   parameter int INPUT_COUNT = 784,
                   parameter int NEURON_COUNT = 128)
(
  input wire clk,
  input wire rst,
  input wire signed [WIDTH-1:0] x_input [INPUT_COUNT-1:0],
  input wire signed [WIDTH-1:0] weight [NEURON_COUNT-1:0][INPUT_COUNT-1:0],
  input wire signed [WIDTH-1:0] bias [NEURON_COUNT-1:0],
  output wire signed [WIDTH-1:0] activate [NEURON_COUNT-1:0],
  output wire complete
);
  localparam int FINAL_CYCLE = (INPUT_COUNT + REDUCTION_PARALLEL_LANES - 1) / REDUCTION_PARALLEL_LANES;

  // since this is fully connected, each neuron can share the same input
  wire signed [WIDTH-1:0] one_cycle_x_input [OUTPUT_PARALLEL_LANES-1:0][REDUCTION_PARALLEL_LANES-1:0];
  wire signed [WIDTH-1:0] one_cycle_weight [OUTPUT_PARALLEL_LANES-1:0][REDUCTION_PARALLEL_LANES-1:0];
  wire signed [2*WIDTH-1:0] accumulate [OUTPUT_PARALLEL_LANES-1:0];
  wire process_next;
  logic [$clog2(FINAL_CYCLE)-1:0] cycles;

  for (genvar i = 0; i < OUTPUT_PARALLEL_LANES; i++) begin : g_parallel_output_x_input
    for (genvar j = 0; j < REDUCTION_PARALLEL_LANES; j++) begin : g_subset_x_input
      assign one_cycle_x_input[i][j] = x_input[i][cycles * REDUCTION_PARALLEL_LANES * j];
    end
  end

  for (genvar i = 0; i < OUTPUT_PARALLEL_LANES; i++) begin : g_parallel_output_weight
    for (genvar j = 0; j < REDUCTION_PARALLEL_LANES; j++) begin : g_subset_weight
      assign one_cycle_weight[i][j] = weight[i][cycles * REDUCTION_PARALLEL_LANES * j];
    end
  end

  MAC_array #() mac_array (.clk(clk), .rst(rst), .complete(complete), .cycles(cycles),
                           .one_cycle_operand_1(one_cycle_x_input),
                           .one_cycle_operand_2(one_cycle_weight),
                           .accumulate(accumulate));

  always_ff @(posedge clk) begin
    if (rst) begin
      cycles <= 0;
    end
    else begin
      if (complete) begin

      end
    end
  end

endmodule
/*

module backup_MAC_array #(parameter int WIDTH = 8,
                   parameter int OUTPUT_PARALLEL_LANES = 4,
                   parameter int REDUCTION_PARALLEL_LANES = 4,
                   parameter int INPUT_COUNT = 784)
(
  input wire clk,
  input wire rst,
  input wire signed [WIDTH-1:0] x_input [OUTPUT_PARALLEL_LANES-1:0][INPUT_COUNT-1:0],
  input wire signed [WIDTH-1:0] weight [OUTPUT_PARALLEL_LANES-1:0][INPUT_COUNT-1:0],
  output reg signed [WIDTH-1:0] accumulate [OUTPUT_PARALLEL_LANES-1:0],
  output reg complete
);

  localparam int FINAL_CYCLE = ceil(INPUT_COUNT / REDUCTION_PARALLEL_LANES);

  wire signed [WIDTH-1:0] one_cycle_x_input [OUTPUT_PARALLEL_LANES-1:0][REDUCTION_PARALLEL_LANES-1:0];
  wire signed [WIDTH-1:0] one_cycle_weight [OUTPUT_PARALLEL_LANES-1:0][REDUCTION_PARALLEL_LANES-1:0];
  wire signed [WIDTH-1:0] one_cycle_accumulate_out [OUTPUT_PARALLEL_LANES-1:0][REDUCTION_PARALLEL_LANES-1:0];
  wire signed [WIDTH-1:0] one_cycle_adder_out [OUTPUT_PARALLEL_LANES-1:0];

  logic [$clog2(FINAL_CYCLE)-1:0] cycle;

  // if reduction parallel = 4, each clock cycle can complete 4 xi*wi per neuron
  for (genvar i = 0; i < OUTPUT_PARALLEL_LANES; i++) begin : g_parallel_output_x_input
    for (genvar j = 0; j < REDUCTION_PARALLEL_LANES; j++) begin : g_subset_x_input
      assign one_cycle_x_input[i][j] = x_input[i][cycle * REDUCTION_PARALLEL_LANES * j];
    end
  end

  for (genvar i = 0; i < OUTPUT_PARALLEL_LANES; i++) begin : g_parallel_output_weight
    for (genvar j = 0; j < REDUCTION_PARALLEL_LANES; j++) begin : g_subset_weight
      assign one_cycle_weight[i][j] = weight[i][cycle * REDUCTION_PARALLEL_LANES * j];
    end
  end

  for (genvar i = 0; i < OUTPUT_PARALLEL_LANES; i++) begin : g_parallel_output
    for (genvar j = 0; j < REDUCTION_PARALLEL_LANES; j++) begin : g_parallel_reduction
      MAC #(.WIDTH(WIDTH)) mac_unit ( .accumulate(accumulate[i]),
                                      .x_input(one_cycle_x_input[i][j]),
                                      .weight(one_cycle_weight[i][j]),
                                      .accumulate_out(one_cycle_accumulate_out[i][j]));
    end
    // one_cycle_accumuate_out[i][j] -> xiwi
    // one_cycle_accumuate_out[i] -> [xiwi, xi+1*wi+1, xi+2*wi+2, xi+3*wi+3]
                                //-> signed_adder_tree -> xnwn
    signed_adder_tree #(.WIDTH(WIDTH), .INPUT_COUNT(REDUCTION_PARALLEL_LANES))
                      add (.in(one_cycle_accumulate_out[i]), .out(one_cycle_adder_out[i]));
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      cycles <= 0;
      accumulate <= '{default: '0};
      complete <= 0;
    end
    else begin
      if (cycle < FINAL_CYCLE) begin
        cycle <= cycles + 1;
        for (int i = 0; i < OUTPUT_PARALLEL_LANES; i++)
            accumulate[i] = accumulate[i] + one_cycle_adder_out[i];
      end
      else begin
        complete <= 1;
      end
    end
  end

endmodule
*/
