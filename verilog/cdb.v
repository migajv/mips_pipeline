`ifndef _cdb
 `define _cdb

 `include "arbiter.v"

module cdb (
	    input 	      clk,
	    input 	      rst,
	    input 	      cdb_req0,
	    input 	      cdb_req1,
	    input [31:0]      cdb_data0,
	    input [3:0]       cdb_tag0,
	    input [31:0]      cdb_data1,
	    input [3:0]       cdb_tag1,
	    

	    output 	      cdb_grant0,
	    output 	      cdb_grant1,
	    output reg [31:0] cdb_data,
	    output reg [3:0]  cdb_tag,
	    output reg 	      cdb_valid
	    
	    );
   
   wire [1:0] 		  cdb_grant;
   

   arbiter #(.WIDTH(2)) u_arbiter_cdb (
				      .req ({cdb_req0, cdb_req1}),
				      .clk (clk),
				      .rst (rst),
				      .enable (1'b1),  // fixme: connect to function unit avail
				      .grant ({cdb_grant0, cdb_grant1}),
				      .anyreq()
				      );   
   
   always @(*) begin
      case ({cdb_grant0,cdb_grant1})
	2'b01: begin
	   cdb_data <= cdb_data1;
	   cdb_tag <= cdb_tag1;
	   cdb_valid <= 1'b1;
	end
	2'b10: begin
	   cdb_data <= cdb_data0;
	   cdb_tag <= cdb_tag0;
	   cdb_valid <= 1'b1;
	end
	default: begin
	   cdb_data <= 0;
	   cdb_tag <= 0;	   
	   cdb_valid <= 1'b0;
	end
      endcase // case rs_grant
   end

   

endmodule // cdb
`endif
