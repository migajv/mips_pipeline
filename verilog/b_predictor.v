`ifndef _B_PREDICTOR_
 `define _B_PREDICTOR_


module b_predictor (
		    input 		clk,
		    input 		rst,

		    input 		direct_mispredict,
		    input 		direct_resolved,
		    input 		branch_commit,
		    input [31:0] 	pc_head, // the pc of commit branch
		    input [31:0] 	pc_branch, // the pc of branch making predict
		    input [31:0] 	pc_resolved,
		    
		    output logic 	branch_valid,
		    output logic [31:0] btb_pc_predict, 
		    output logic 	direct_predict
		    );


   logic [3:0] local_b [63:0];
   logic [3:0] local_b_checkpoint [63:0];
   logic [1:0] counters [15:0];
   
   integer     i;
   
   logic [5:0] pc_head_index, pc_branch_index;
   assign pc_head_index = pc_head[7:2];
   assign pc_branch_index = pc_branch[7:2];

   assign direct_predict = counters[local_b[pc_branch_index]] > 1;

   //speculative local history, not actually used in this implementation
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 for(i = 0; i < 64; i = i + 1) begin
	    local_b[i] <= 4'h0;
	 end
      end
      else begin
	 if (direct_mispredict) begin
	    //update history if mispredict
	    local_b[pc_head_index] <= (local_b_checkpoint[pc_head_index] << 1) | direct_resolved;
	 end
	 if (branch_valid) begin
	    //insert predicted direction to local branch history
	    local_b[pc_branch_index] <= (local_b[pc_branch_index] << 1) | (counters[local_b[pc_branch_index]] > 1 ? 4'h1 : 4'h0);
	 end
      end
   end // always @ (posedge clk, negedge rst)

   // commited local history, used in this implementation
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 for(i = 0; i < 64; i = i + 1) begin
	    local_b_checkpoint[i] <= 4'h0;
	 end
      end
      else begin   
	 if (branch_commit) begin
	    local_b_checkpoint[pc_head_index] <= (local_b_checkpoint[pc_head_index] << 1) | direct_resolved;
	 end
      end
   end // always @ (posedge clk, negedge rst)
   
   //saturated counter  0:deep untaken, 1:untaken, 2:taken, 3:deep taken
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 for(i = 0; i < 16; i = i + 1) begin
	    counters[i] <= 2'h1;
	 end
      end
      else begin
	 if (branch_commit) begin
	    if (direct_resolved) begin
	       if (counters[local_b_checkpoint[pc_head_index]] < 4'h3) begin
		  counters[local_b_checkpoint[pc_head_index]] <= counters[local_b_checkpoint[pc_head_index]] + 1;
	       end
	    end
	    else begin
	       if (counters[local_b_checkpoint[pc_head_index]] > 4'h0) begin
		  counters[local_b_checkpoint[pc_head_index]] <= counters[local_b_checkpoint[pc_head_index]] - 1;
	       end	       
	    end
	 end // if (branch_commit)
      end // else: !if(!rst)
   end // always @ (posedge clk, negedge rst)
   
	
   typedef struct packed{
      bit [23:0]  pc_branch_tag;
      bit [31:0]  btb_pc_predict;
      bit 	  bsy;
   } btbStruct;

   btbStruct btb_array[63:0];


   //for simplicity, use pc indexed btb; should use associative one
   //fixme: to implement replace policy
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 for (i = 0; i < $size(btb_array); i = i + 1) begin
	    btb_array[i] <= {$size(btbStruct){1'b0}};
	 end
      end
      else begin
	 if (branch_commit) begin
	    btb_array[pc_head_index].bsy <= 1'b1;
	    btb_array[pc_head_index].pc_branch_tag <= pc_head[31:8];
	    //only updated target pc when it is actually taken
	    if (direct_resolved) begin
	       btb_array[pc_head_index].btb_pc_predict <= pc_resolved;
	    end
	 end
      end // else: !if(!rst)
   end // always @ (posedge clk, negedge rst)

   assign branch_valid = btb_array[pc_branch_index].bsy;
   
   assign btb_pc_predict = (btb_array[pc_branch_index].bsy && btb_array[pc_branch_index].pc_branch_tag == pc_branch[31:8]) ? btb_array[pc_branch_index].btb_pc_predict : 32'h0;
   
	   

endmodule // b_predictor

`endif //  `ifndef _B_PREDICTOR_
