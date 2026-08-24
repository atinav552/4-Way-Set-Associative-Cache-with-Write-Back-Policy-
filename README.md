# 4-Way Set-Associative Cache with Write-Back Policy

## Overview
A parameterizable Level-1 Set-Associative Cache implemented in standard Verilog-2001. The architecture uses a 4-way set-associative memory mapping and implements a strict Write-Back and Write-Allocate policy to minimize main memory traffic.

Memory block evictions are managed dynamically by a hardware-level Least Recently Used (LRU) replacement algorithm.

## Architecture Highlights
* **Parameterizable Design:** The number of sets, ways, tag bits, and data widths can be scaled dynamically via instantiation parameters.
* **Hit/Miss Detection:** Parallel tag comparison across all ways within a targeted set to resolve access requests within a single clock cycle.
* **LRU Replacement Logic:** Hardware ranking system that promotes accessed lines to Most Recently Used (MRU) and evicts the lowest-ranked line during a cache miss.
* **Dirty-Bit Tracking:** Monitors write operations to ensure only modified (dirty) cache lines trigger a write-back request (`wb_req`) to main memory upon eviction, ignoring clean evictions.

## Verification
The repository includes an automated testbench (`tb.v`) that validates core cache operations:
1. **Read Hits:** Verifies correct data retrieval on matching tags.
2. **Dirty Evictions:** Ensures `wb_req` triggers when a modified line is replaced.
3. **Clean Evictions:** Confirms `wb_req` remains low when replacing unmodified data.
4. **Write-Allocate:** Validates that a write-miss correctly allocates a new cache line and marks it as dirty.

## Simulation Instructions
The RTL and testbench can be compiled and visualized using open-source simulation tools.
