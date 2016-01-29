/*
 * Data Memory.
 *
 * 32-bit data with a 7 bit address (128 entries).
 *
 * The read and write operations operate somewhat independently.
 *
 * Any time the read signal (rd) is high the data stored at the
 * given address (addr) will be placed on 'rdata'.
 *
 * Any time the write signal (wr) is high the data on 'wdata' will
 * be stored at the given address (addr).
 * 
 * If a simultaneous read/write is performed the data written
 * can be immediately read out.
 */

`ifndef _dm
 `define _dm

module dm(
          input wire 	     clk,
	  input wire 	     rst,
          input wire [6:0]   waddr,
	  input wire [6:0]   raddr,
          input wire 	     wr,
          input wire [31:0]  wdata,
          output wire [31:0] rdata);
   
   reg [31:0] 		     mem [0:127];  // 32-bit memory with 128 entries
   integer 		     i;
   
   
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 for (i = 0; i < 128; i=i+1) begin
	    mem[i] <= 32'h0000;
	 end
	 #1 mem[20] <= 32'd10;
	 mem[21] <= 32'h3;
      end
      else if (wr) begin
         mem[waddr] <= wdata;
      end
   end

   assign rdata = mem[raddr][31:0];
   // During a write, avoid the one cycle delay by reading from 'wdata'
   
endmodule

`endif
