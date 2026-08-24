// ============================================================
// Write-back set-associative cache (Standard Verilog-2001)
// ============================================================

module wb_cache #(
  parameter NUM_SETS   = 4,
  parameter NUM_WAYS   = 4,
  parameter TAG_BITS   = 4,
  parameter DATA_WIDTH = 8,
  parameter SET_BITS   = 2, // Equivalent to $clog2(NUM_SETS)
  parameter WAY_BITS   = 2  // Equivalent to $clog2(NUM_WAYS)
) (
  input  wire                  clk,
  input  wire                  rst_n,
  input  wire                  access,
  input  wire                  write_en,
  input  wire [TAG_BITS-1:0]   addr_tag,
  input  wire [SET_BITS-1:0]   addr_set,
  input  wire [DATA_WIDTH-1:0] write_data,
  
  output wire [DATA_WIDTH-1:0] read_data,
  output wire                  hit,
  output wire                  miss,
  output wire                  wb_req,
  output wire [TAG_BITS-1:0]   wb_tag,
  output wire [SET_BITS-1:0]   wb_set,
  output wire [DATA_WIDTH-1:0] wb_data
);

  localparam LRU_BITS = WAY_BITS;

  // -----------------------------------------------------------------------
  // Cache Storage Arrays
  // -----------------------------------------------------------------------
  reg                  valid [0:NUM_SETS-1][0:NUM_WAYS-1];
  reg                  dirty [0:NUM_SETS-1][0:NUM_WAYS-1];
  reg [TAG_BITS-1:0]   tags  [0:NUM_SETS-1][0:NUM_WAYS-1];
  reg [DATA_WIDTH-1:0] data  [0:NUM_SETS-1][0:NUM_WAYS-1];
  reg [LRU_BITS-1:0]   lru   [0:NUM_SETS-1][0:NUM_WAYS-1];

  reg [WAY_BITS-1:0] hit_way;
  reg [WAY_BITS-1:0] victim_way;
  reg                any_hit;
  reg                all_valid;

  // Standard Verilog requires loop variables to be declared outside
  integer w, s;
  reg [LRU_BITS-1:0] old_rank;

  // -----------------------------------------------------------------------
  // 1. Hit Detection Logic
  // -----------------------------------------------------------------------
  always @(*) begin
    any_hit = 1'b0;
    hit_way = 0;
    for (w = 0; w < NUM_WAYS; w = w + 1) begin
      if (valid[addr_set][w] && (tags[addr_set][w] == addr_tag)) begin
        any_hit = 1'b1;
        hit_way = w[WAY_BITS-1:0];
      end
    end
  end

  // -----------------------------------------------------------------------
  // 2. Victim Selection Logic (LRU)
  // -----------------------------------------------------------------------
  always @(*) begin
    all_valid  = 1'b1;
    victim_way = 0;

    for (w = 0; w < NUM_WAYS; w = w + 1) begin
      if (!valid[addr_set][w]) begin
        all_valid = 1'b0;
      end
    end

    if (all_valid) begin
      for (w = 0; w < NUM_WAYS; w = w + 1) begin
        if (lru[addr_set][w] == 0) begin
          victim_way = w[WAY_BITS-1:0];
        end
      end
    end else begin
      for (w = NUM_WAYS-1; w >= 0; w = w - 1) begin
        if (!valid[addr_set][w]) begin
          victim_way = w[WAY_BITS-1:0];
        end
      end
    end
  end

  // -----------------------------------------------------------------------
  // 3. Output Routing & Writeback Requests
  // -----------------------------------------------------------------------
  assign hit       = access && any_hit;
  assign miss      = access && !any_hit;
  assign read_data = data[addr_set][hit_way];
  
  assign wb_req    = miss && valid[addr_set][victim_way] && dirty[addr_set][victim_way];
  assign wb_tag    = tags[addr_set][victim_way];
  assign wb_set    = addr_set;
  assign wb_data   = data[addr_set][victim_way];

  // -----------------------------------------------------------------------
  // 4. Sequential Memory Updates
  // -----------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (s = 0; s < NUM_SETS; s = s + 1) begin
        for (w = 0; w < NUM_WAYS; w = w + 1) begin
          valid[s][w] <= 1'b0;
          dirty[s][w] <= 1'b0;
          tags[s][w]  <= 0;
          data[s][w]  <= 0;
          lru[s][w]   <= w[LRU_BITS-1:0]; 
        end
      end
    end else if (access) begin
      
      if (any_hit) begin
        // ---- HIT PROCESSING ----
        if (write_en) begin
          data[addr_set][hit_way]  <= write_data;
          dirty[addr_set][hit_way] <= 1'b1; 
        end
        
        old_rank = lru[addr_set][hit_way];
        for (w = 0; w < NUM_WAYS; w = w + 1) begin
          if (w[WAY_BITS-1:0] == hit_way) begin
            lru[addr_set][w] <= (NUM_WAYS - 1); 
          end else if (lru[addr_set][w] > old_rank) begin
            lru[addr_set][w] <= lru[addr_set][w] - 1'b1; 
          end
        end

      end else begin
        // ---- MISS PROCESSING (Evict & Fill) ----
        valid[addr_set][victim_way] <= 1'b1;
        dirty[addr_set][victim_way] <= write_en; 
        tags[addr_set][victim_way]  <= addr_tag;
        data[addr_set][victim_way]  <= write_data;
        
        old_rank = lru[addr_set][victim_way];
        for (w = 0; w < NUM_WAYS; w = w + 1) begin
          if (w[WAY_BITS-1:0] == victim_way) begin
            lru[addr_set][w] <= (NUM_WAYS - 1); 
          end else if (lru[addr_set][w] > old_rank) begin
            lru[addr_set][w] <= lru[addr_set][w] - 1'b1; 
          end
        end
      end
    end
  end

endmodule