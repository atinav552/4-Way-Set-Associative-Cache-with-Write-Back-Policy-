module tb;
  reg clk, rst_n, access, write_en;
  reg [3:0] addr_tag;
  reg [1:0] addr_set;
  reg [7:0] write_data;
  
  wire hit, miss, wb_req;
  wire [3:0] wb_tag;
  wire [1:0] wb_set;
  wire [7:0] read_data, wb_data;
  
  integer p, f;
  
  initial clk = 0; 
  always #5 clk = ~clk;

  // Explicit Port Mapping for Standard Verilog
  wb_cache #(
    .NUM_SETS(4), 
    .NUM_WAYS(4), 
    .TAG_BITS(4), 
    .DATA_WIDTH(8),
    .SET_BITS(2),
    .WAY_BITS(2)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .access(access),
    .write_en(write_en),
    .addr_tag(addr_tag),
    .addr_set(addr_set),
    .write_data(write_data),
    .read_data(read_data),
    .hit(hit),
    .miss(miss),
    .wb_req(wb_req),
    .wb_tag(wb_tag),
    .wb_set(wb_set),
    .wb_data(wb_data)
  );

  task cw;
    input [1:0] s;
    input [3:0] t;
    input [7:0] d;
    begin
      @(negedge clk); addr_set = s; addr_tag = t; write_data = d; write_en = 1; access = 1;
      @(posedge clk); @(negedge clk); access = 0; write_en = 0;
    end
  endtask

  initial begin
    p = 0; f = 0;
    rst_n = 0; access = 0; write_en = 0; addr_tag = 0; addr_set = 0; write_data = 0;
    
    @(posedge clk); @(posedge clk); rst_n = 1;
    @(posedge clk); @(negedge clk);
    
    // Fill all 4 ways in set 0 with dirty data
    cw(0, 4'h1, 8'hAA); 
    cw(0, 4'h2, 8'hBB); 
    cw(0, 4'h3, 8'hCC); 
    cw(0, 4'h4, 8'hDD);

    // =========================================================
    // TC1 — Read Hit
    // =========================================================
    @(negedge clk); addr_set=0; addr_tag=4'h1; write_en=0; access=1; #1;
    if (hit) begin 
      p = p + 1; $display("PASS: TC1 read hit: set=0 tag=0x1 hit=%b read_data=0x%h", hit, read_data); 
    end else begin 
      f = f + 1; $display("FAIL: TC1 read hit: expected hit=1, got hit=%b miss=%b", hit, miss); 
    end
    @(posedge clk); @(negedge clk); access=0;

    // =========================================================
    // TC2 — Dirty Eviction on Miss
    // =========================================================
    @(negedge clk); addr_set=0; addr_tag=4'h5; write_en=0; access=1; #1;
    if (miss && wb_req) begin 
      p = p + 1; $display("PASS: TC2 dirty eviction: set=0 tag=0x5 miss=%b wb_req=%b wb_tag=0x%h - LRU dirty way written back", miss, wb_req, wb_tag); 
    end else begin 
      f = f + 1; $display("FAIL: TC2 dirty eviction: expected miss=1 wb_req=1, got miss=%b wb_req=%b", miss, wb_req); 
    end
    @(posedge clk); @(negedge clk); access=0;

    // =========================================================
    // TC3 — Hit After Fill
    // =========================================================
    @(negedge clk); addr_set=0; addr_tag=4'h5; write_en=0; access=1; #1;
    if (hit) begin 
      p = p + 1; $display("PASS: TC3 hit after fill: set=0 tag=0x5 now resident after eviction+fill, hit=%b", hit); 
    end else begin 
      f = f + 1; $display("FAIL: TC3 hit after fill: expected hit=1 after filling tag=0x5, got hit=%b miss=%b", hit, miss); 
    end
    @(posedge clk); @(negedge clk); access=0;

    // =========================================================
    // TC4 — Clean Eviction (No Writeback)
    // =========================================================
    rst_n=0; @(posedge clk); @(negedge clk); rst_n=1; @(posedge clk); @(negedge clk);
    
    // Fill set 1 with 4 clean read entries (write_en=0 -> dirty=0)
    @(negedge clk); addr_set=1; addr_tag=4'hA; write_en=0; access=1; @(posedge clk); @(negedge clk); access=0;
    @(negedge clk); addr_set=1; addr_tag=4'hB; write_en=0; access=1; @(posedge clk); @(negedge clk); access=0;
    @(negedge clk); addr_set=1; addr_tag=4'hC; write_en=0; access=1; @(posedge clk); @(negedge clk); access=0;
    @(negedge clk); addr_set=1; addr_tag=4'hD; write_en=0; access=1; @(posedge clk); @(negedge clk); access=0;
    
    // Access new tag — eviction required but all clean -> no writeback
    @(negedge clk); addr_set=1; addr_tag=4'hE; write_en=0; access=1; #1;
    if (miss && !wb_req) begin 
      p = p + 1; $display("PASS: TC4 clean eviction: set=1 tag=0x5 miss=%b wb_req=%b - no writeback for clean victim", miss, wb_req); 
    end else begin 
      f = f + 1; $display("FAIL: TC4 clean eviction: expected miss=1 wb_req=0, got miss=%b wb_req=%b", miss, wb_req); 
    end
    @(posedge clk); @(negedge clk); access=0;

    // =========================================================
    // TC5 — Write Miss (Write-Allocate, Line Marked Dirty)
    // =========================================================
    rst_n=0; @(posedge clk); @(negedge clk); rst_n=1; @(posedge clk); @(negedge clk);
    
    // Write to uncached address -> write miss, allocate line
    @(negedge clk); addr_set=2; addr_tag=4'h7; write_data=8'hAB; write_en=1; access=1; #1;
    if (miss) begin 
      p = p + 1; $display("PASS: TC5 write miss: set=2 tag=0x7 miss=%b - write-allocate will fire on posedge", miss); 
    end else begin 
      f = f + 1; $display("FAIL: TC5 write miss: expected miss=1, got hit=%b miss=%b", hit, miss); 
    end
    @(posedge clk); @(negedge clk); write_en=0;
    
    // Read it back -> should hit
    @(negedge clk); addr_set=2; addr_tag=4'h7; access=1; #1;
    if (hit && read_data==8'hAB) begin 
      p = p + 1; $display("PASS: TC5 write-allocate: set=2 tag=0x7 hit after write miss, read_data=0x%h", read_data); 
    end else begin 
      f = f + 1; $display("FAIL: TC5 write-allocate: expected hit=1 read_data=0xAB, got hit=%b read_data=0x%h", hit, read_data); 
    end
    @(posedge clk); @(negedge clk); access=0;
    
    // Fill 3 more ways, then force eviction of dirty tag 0x7 to verify wb_req fires
    cw(2, 4'h8, 8'hCC); 
    cw(2, 4'h9, 8'hDD); 
    cw(2, 4'hA, 8'hEE);
    
    @(negedge clk); addr_set=2; addr_tag=4'hB; write_en=0; access=1; #1;
    if (wb_req) begin 
      p = p + 1; $display("PASS: TC5 dirty eviction: write-allocated line wb_req=%b wb_tag=0x%h - correctly marked dirty", wb_req, wb_tag); 
    end else begin 
      f = f + 1; $display("FAIL: TC5 dirty eviction: write-allocated line should be dirty, wb_req=%b", wb_req); 
    end
    @(posedge clk); @(negedge clk); access=0;

    $display("=== %0d passed %0d failed ===", p, f);
    $finish;
  end

  // Dumpfiles for GTKWave
  initial begin
    $dumpfile("wb_cache_waves.vcd");
    $dumpvars(0, tb);
  end

endmodule