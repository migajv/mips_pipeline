`ifndef _regstatus
 `define _regstatus

// two read ports, two write port
module regstatus (
		  input        clk,
		  input        rst,
		  input        wr_regs_en,
		  input [4:0]  wr_regs_tag,
		  input [3:0]  wr_regs_rb_tag,
		  input [4:0]  rd_reg_tag1,
		  input [4:0]  rd_reg_tag2,
		  input        commit_en,
		  input [4:0]  commit_reg_tag,
		  input        flush_regs,
		  
		  output [3:0] rd_rb_tag1,
		  output       rd_bsy1,
		  output [3:0] rd_rb_tag2,
		  output       rd_bsy2
		  );

   typedef struct packed {
      bit [3:0]   rb_tag;
      bit 	  bsy;
   }regstatusStruct;

   regstatusStruct regs_array [31:0];


   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 for ( int i = 0; i < $size(regs_array); i++) begin
	    regs_array[i] <= {$size(regstatusStruct){1'b0}};
	 end
      end   
      else begin
	 if (flush_regs) begin
	    for ( int i = 0; i < $size(regs_array); i++) begin
	       regs_array[i] <= {$size(regstatusStruct){1'b0}};
	    end	    
	 end
	 else begin
	    if (wr_regs_en) begin  
	       regs_array[wr_regs_tag].rb_tag <= wr_regs_rb_tag;
	       regs_array[wr_regs_tag].bsy <= 1'b1;
	    end
	    if (commit_en) begin
	       //wr_regs_en has higher priority
	       if (!(wr_regs_en && wr_regs_tag == commit_reg_tag)) begin
		  regs_array[commit_reg_tag].bsy <= 1'b0;
	       end
	    end
	 end
      end
   end // always @ (posedge clk, negedge rst)

   
   assign rd_rb_tag1 = regs_array[rd_reg_tag1].rb_tag;
   assign rd_bsy1    = regs_array[rd_reg_tag1].bsy;
   assign rd_rb_tag2 = regs_array[rd_reg_tag2].rb_tag;
   assign rd_bsy2    = regs_array[rd_reg_tag2].bsy;
   
endmodule // regstatus

`endif
