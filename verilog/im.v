/*
 * im.v - instruction memory
 *
 * Given a 32-bit address the data is latched and driven
 * on the rising edge of the clock.
 *
 * Currently it supports 7 address bits resulting in
 * 128 bytes of memory.  The lowest two bits are assumed
 * to be byte indexes and ignored.  Bits 8 down to 2
 * are used to construct the address.
 *
 * The memory is initialized using the Verilog $readmemh
 * (read memory in hex format, ascii) operation. 
 * The file to read from can be configured using .IM_DATA
 * parameter and it defaults to "im_data.txt".
 * The number of memory records can be specified using the
 * .NMEM parameter.  This should be the same as the number
 * of lines in the file (wc -l im_data.txt).
 */

`ifndef _im
 `define _im

module im(
	  input wire 	      clk,
	  input wire 	      rst,
	  input wire [31:0]   addr,
	  input wire [31:0]   im_add,
	  input wire [31:0]   im_data,
	  input wire 	      im_en,
	  input wire 	      im_rd_wr,
	  input 	      stall,
	  input 	      mispredict,
	  
	  output logic [31:0] inst1,
	  output logic [31:0] inst1_pc,
	  output logic 	      inst1_valid
	  );

   parameter NMEM = 128;   // Number of memory entries,
   // not the same as the memory size
   parameter IM_DATA = "im_data.txt";  // file to read data from

   reg [31:0] 		     mem [0:127];  // 32-bit memory with 128 entries
   integer 		     i;
   
   initial 
     begin
	//$readmemh(IM_DATA, mem, 0, NMEM-1);

     end

   // without clk to let driver fist write instructions into im
   always @(*) begin
      if (!rst) begin
	 for (i = 0; i < 128; i=i+1) begin
	    mem[i] <= 32'h0;
	 end
      end
      else if (im_rd_wr) begin
	 mem[im_add] <= im_data;
      end
   end

   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 inst1 <= 32'h0;
	 inst1_valid <= 1'b0;
	 inst1_pc <= 32'h0;
      end
      else if (stall || mispredict) begin
	 inst1 <= 32'h0;
	 inst1_valid <= 1'b0;
	 inst1_pc <= 32'h0;
      end
      else begin
	 inst1 <= mem[addr[8:2]][31:0];
	 inst1_valid <= 1'b1;
	 inst1_pc <= addr;
      end
   end
   
endmodule

`endif
