`ifndef _iq_
 `define _iq_

// instruction queue
module iq(
	  input 	      clk,
	  input 	      rst,
	  input 	      inst1_in_valid,
	  input [31:0] 	      inst1_in,
	  input 	      inst2_in_valid,
	  input [31:0] 	      inst2_in,
	  input 	      stall_backend,
	  input 	      mispredict,
	  input 	      singlemode,  // single width
	  
	  output logic 	      iq_empty,
	  output logic 	      iq_full,
	  output logic 	      inst1_out_valid,
	  output logic [31:0] inst1_out,
	  output logic 	      inst2_out_valid,
	  output logic [31:0] inst2_out
	  );

   logic [31:0] 	iq_array [15:0] ;
   logic [4:0] 		iq_head_ext;
   logic [4:0] 		iq_tail_ext;
   logic [3:0] 		iq_head;
   logic [3:0] 		iq_tail;
   logic 		iq_near_empty;
   logic 		iq_near_full;
   logic 		iq_real_empty;
   logic 		iq_real_full;   

   
   assign iq_head = iq_head_ext[3:0];
   assign iq_tail = iq_tail_ext[3:0];

   assign iq_real_empty = (iq_head_ext == iq_tail_ext);
   assign iq_near_empty = (iq_head_ext + 1 == iq_tail_ext);
   
   assign iq_real_full = (iq_head_ext != iq_tail_ext) && (iq_head == iq_tail);
   assign iq_near_full = (iq_head_ext != iq_tail_ext + 1) && (iq_head == iq_tail + 1);

   assign iq_empty = iq_real_empty || iq_near_empty;
   assign iq_full = iq_real_full || iq_near_full;
   
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 iq_tail_ext <= 5'b0;
	 iq_head_ext <= 5'b0;
	 inst1_out_valid <= 1'b0;
	 inst2_out_valid <= 1'b0;
	 inst1_out <= 32'h0;
	 inst2_out <= 32'h0;
         for ( int i = 0; i < $size(iq_array) ; i++) begin
            iq_array[i] <= {32{1'b0}};
         end
      end	 
      else begin
	 // enqueue 2 instructions
	 if (inst1_in_valid && inst2_in_valid && !iq_near_full && !iq_real_full && !singlemode) begin
	    iq_array[iq_tail] <= inst1_in;
	    iq_array[iq_tail+1] <= inst2_in;
	    iq_tail_ext <= iq_tail_ext + 2;
	 end
	 // enqueue 1 instruction
	 else if (inst1_in_valid && !inst2_in_valid && !iq_real_full) begin
	    iq_array[iq_tail] <= inst1_in;
	    iq_tail_ext <= iq_tail_ext + 1;
	 end

	 if (stall_backend) begin
	    inst1_out_valid <= 1'b0;
	    inst2_out_valid <= 1'b0;
	 end
	 //dequeue 2 instructions
	 else if (!iq_near_empty && !iq_real_empty && !singlemode) begin
	    iq_head_ext <= iq_head_ext + 2;
	    inst1_out_valid <= 1'b1;
	    inst1_out <= iq_array[iq_head];
	    inst2_out_valid <= 1'b1;
	    inst2_out <= iq_array[iq_head+1];
	 end
	 //dequeue 1 instruction
	 else if ((iq_near_empty && !iq_real_empty && !singlemode) ||
		                    (!iq_real_empty && singlemode)) begin
	    iq_head_ext <= iq_head_ext + 1;
	    inst1_out_valid <= 1'b1;
	    inst1_out <= iq_array[iq_head];
	    inst2_out_valid <= 1'b0;
	 end
	 else begin
	    inst1_out_valid <= 1'b0;
	    inst2_out_valid <= 1'b0;
	 end
      end // else: !if(!rst)
   end // always @ (posedge clk, negedge rst)
	    
endmodule // iq

`endif


