`ifndef _arbiter
 `define _arbiter

module arbiter
  #( parameter integer WIDTH            = 2)
   (
    input [WIDTH-1:0] 	   req,
    input 		   enable,
    input 		   clk,
    input 		   rst,
    output reg [WIDTH-1:0] grant,
    output 		   anyreq
    );

   parameter P_WIDTH = $clog2(WIDTH);

   logic [P_WIDTH-1:0] 	   pointer;
   logic [2*WIDTH-1:0] 	   req_shifted_double;
   logic [WIDTH-1:0] 	   req_shifted;
   logic [2*WIDTH-1:0] 	   grant_shifted_double;
   logic [WIDTH-1:0] 	   grant_shifted;
 
   
   assign req_shifted_double = {req,req} >> pointer;
   assign req_shifted = req_shifted_double[WIDTH-1:0];

   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 pointer <= 0;
      end
      else begin
	 if (pointer < WIDTH -1) begin
	    pointer <= pointer + 1;
	 end
	 else begin
	    pointer <= 0;
	 end
      end // else: !if(!rst)
   end // always @ (posedge clk, negedge rst)
   
   
   assign anyreq = |req;
   genvar 	       i;

   always @(*) begin
      grant_shifted = {WIDTH{1'b0}};
      if (enable) begin	    
	 for (int i = 0; i < WIDTH; i = i + 1) begin
	    if (req_shifted[i]) begin
	       grant_shifted[i] = 1'b1;
	       break;
	    end
	 end	       
      end
   end

   assign grant_shifted_double = {grant_shifted, grant_shifted} << pointer;
   assign grant = grant_shifted_double[2*WIDTH-1:WIDTH];

endmodule // arbiter

`endif //  `ifndef _arbiter
