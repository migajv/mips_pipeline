`ifndef _rs
 `define _rs

module rs (
	   input       rst,
	   input       clk,

	   input [4:0] rs,
	   input [4:0] rt,
	   input [3:0] dest, // tag of rb

	   input [3:0] rd_rb_tag1,
	   input       rd_bsy1,
	   input [3:0] rd_rb_tag2,
	   input       rd_bsy2,
	   input       inst_valid, // when to insert a new entry

	   
	   output      avail, //if there is any empty entry
	   
	   );

   typedef struct packed{
      bit [2:0]   tag;
      int 	  s1;
      int 	  s2;
      bit [4:0]   dest;
      bit 	  rdy_s1;
      bit 	  rdy_s2;
      bit 	  bsy;
      bit 	  rdy_result;
   } rsStruct;

   rsStruct rs_array [7:0];

   reg   bsy = 1;
   always @(*) begin
      for (int i = 0; i < $size(rs_array); i++) begin   
	 bsy = bsy & rs_array[i].bsy ;
      end
   end
   assign avail = ~bsy;   
      
   reg [2:0] tail; //point to next empty entry
   
   // priority encoder
   always @(*) begin
      if (avail == 1'b1) begin
	 for (int i = 0; i < $size(rs_array); i++) begin
	    if (rs_array[i].bsy == 1'b0) begin
	       tail = i;
	       break;
	    end
	 end
      end
   end // always @ begin
   
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 for ( int i = 0; i < $size(rs_array) ; i++) begin
	    rs_array[i] <= {$size(rsStruct){1'b0}};
	 end
      end
      else if (inst_valid) begin
	 if (rd_bsy1) begin
	    


       
   

   
