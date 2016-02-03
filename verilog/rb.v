`ifndef _rb
 `define _rb 

 `include "arbiter.v"
 `include "cdb.v"
 `include "b_predictor.v"
 `include "rs.v"

module rb (
           input 	       rst,
           input 	       clk,

	   input 	       inst_valid,
           input [2:0] 	       inst_type,
           input [4:0] 	       rs,
           input [4:0] 	       rt,
           input [4:0] 	       rd,
           input [15:0]        imm,
	   input [31:0]        seimm,
	   input [31:0]        seimm_sl2,
           input [31:0]        pc4,
           input [5:0] 	       funct,
           input [5:0] 	       opcode, 
	   input [31:0]        pc4_undly,
	   
           input [4:0] 	       wr_dest,
           input 	       wr_dest_en, // when rs finish exe and to update rb dest (from AGU)
           input [3:0] 	       wr_dest_tag, 

           input [3:0] 	       rd_rb_tag1, // return from RegisterStatus
           input 	       rd_bsy1,
           input [3:0] 	       rd_rb_tag2,
           input 	       rd_bsy2,

           input [31:0]        reg_rs, //return from register memory
           input [31:0]        reg_rt,

           input [31:0]        lsu_addr, //return from AGU

           input [31:0]        mem_value, // value from dm
           //input 	       mem_valid, // when mem_value is valid

           input [31:0]        alu_out, // to cdb

           output logic        stall, // stall if no empty rb or rs entry

           output logic [31:0] pc_predict,
           output logic        predict_taken,
           output logic        predict_valid,
           output logic        mispredict,
           output logic [31:0] pc_resolved,

           output logic [6:0]  commit_dest, // mem addr: 7 bits, reg addr: 5 bits
           output logic [31:0] commit_value,
           output logic        commit_mem_valid, // when to commit to mem
           output logic        commit_reg_valid, // when to commit to reg

           output logic        wr_regs_en, //write to reg status
           output logic [4:0]  wr_regs_tag,
           output logic [3:0]  wr_regs_rb_tag,
	   
           output logic [31:0] lsu_s1, // output s1 and A to addr calculating ALU
           output logic [31:0] lsu_A,

           output logic [31:0] alusrc1,
           output logic [31:0] alusrc2,
           output logic [5:0]  alufunct,
           output logic [5:0]  aluopcode,

	   //output logic        mem_wr,
           output logic [6:0]  mem_addr // load mem addr
           );
   
 `define RS_WIDTH 4
 `define RS_TAG_WIDTH 2 // log2 of RS_WIDTH

 `define ALU 3'h0
 `define LOAD 3'h1
 `define STORE 3'h2
 `define BRANCH 3'h3
 `define EMPTY 3'h4
   /* -----\/----- EXCLUDED -----\/-----
    tag 4| type 2| dest 5| value 32| bsy 1| rdy 1
    --------------------------------------
    head -> | 0     0(ALU)
    --------------------------------------  
    | 1     1(MEM) 
    --------------------------------------
    tag  -> | 2     2(BRA) 
    -------------------------------------- 
    tail -> | 3     empty 
    --------------------------------------  
    -----/\----- EXCLUDED -----/\----- */

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
logic [3:0]		rs_req;			// From u_rs1 of rs.v
// End of automatics

   
   //-----------------------------------------------------------------
   //                 Reorder Buffer (rb)
   //-----------------------------------------------------------------  

   
   logic                       cdb_valid;
   logic [31:0]                cdb_data;
   logic [3:0]                 cdb_tag; //tag
   logic 		       cdb_grant0; //for alu
   logic 		       cdb_grant1; //for lsu
   
   logic                       rb_avail;
   
   
   logic                       struct_avail;
   logic [3:0] 		       cdb_tag0;
   logic 		       lsu_bsy;
   logic [3+1:0] 	       rb_head_ext, rb_tail_ext; //1 bit overhead to detect full
   logic [3:0] 		       rb_head, rb_tail;
   logic                       rb_bsy;
   logic 		       rdy_s1_dly;
   
   logic [`RS_TAG_WIDTH-1:0]   lsu_tail; //point to next empty entry
   logic [`RS_TAG_WIDTH-1:0]   lsu_head; //point to queue head

   logic [`RS_TAG_WIDTH-1:0]   store_tail; 
   logic [`RS_TAG_WIDTH-1:0]   store_head; 
   logic [`RS_TAG_WIDTH-1:0]   load_tail; 
   logic [`RS_TAG_WIDTH-1:0]   load_head; 

   logic 		       lsu_addr_done;
   logic 		       mem_done;
   logic 		       lsu_avail;
   logic 		       pc_mispredict;
   logic 		       direct_mispredict;
   logic 		       direct_resolved;
   logic 		       branch_commit;
   logic [31:0] 	       pc_head;
   logic [31:0] 	       pc_branch;
   logic 		       direct_predict;   
   logic [31:0]		       btb_pc_predict;
   logic 		       rs_avail;
   logic 		       branch_valid;
   logic [31:0] 	       btb_pc_predict_dly;
   logic 		       direct_predict_dly;
   

   
   assign struct_avail = (inst_type == `LOAD || inst_type == `STORE) ? rb_avail & lsu_avail : rb_avail & rs_avail; 
   assign stall = ~struct_avail;
   assign rb_head = rb_head_ext[3:0];
   assign rb_tail = rb_tail_ext[3:0];
   
   typedef struct              packed {
      bit [2:0]                inst_type;
      bit [6:0]                dest; //mem addr: 7 bits, reg addr: 5 bits
      bit [31:0]               value;
      bit                      bsy;
      bit                      rdy;
      bit                      predict_taken; // predicted dirction 1:taken, 0: untaken
      bit                      predict_valid;
      bit [31:0]               pc_predict;
      bit [31:0]               pc_taken;
      bit [31:0]               pc4;      // following pc if untaken
   } rbStruct;

   rbStruct  rb_array[15:0];

   int                         size_struct = $size(rbStruct);
   
   /* -----\/----- EXCLUDED -----\/-----
    reg                       rb_bsy;
    always @(*) begin
    rb_bsy = rb_array[0].bsy;
    
    for (int i = 1; i < $size(rb_array); i++) begin   
    rb_bsy = rb_bsy & rb_array[i].bsy ;
      end
   end
    -----/\----- EXCLUDED -----/\----- */

   assign rb_bsy = rb_array[0].bsy & rb_array[1].bsy & rb_array[2].bsy & rb_array[3].bsy &
                   rb_array[4].bsy & rb_array[5].bsy & rb_array[6].bsy & rb_array[7].bsy &
                   rb_array[8].bsy & rb_array[9].bsy & rb_array[10].bsy & rb_array[11].bsy &
                   rb_array[12].bsy & rb_array[13].bsy & rb_array[14].bsy & rb_array[15].bsy ;
   
   
   assign rb_avail = ~rb_bsy;

   
   // for branch, value is output from ALU. only consider BNE here
   assign direct_mispredict = rb_array[rb_head].rdy && rb_array[rb_head].inst_type == `BRANCH &&
		       ((rb_array[rb_head].predict_taken && rb_array[rb_head].value == 0) ||
			(~rb_array[rb_head].predict_taken && rb_array[rb_head].value != 0));

   assign pc_mispredict = rb_array[rb_head].rdy && rb_array[rb_head].inst_type == `BRANCH &&
			  rb_array[rb_head].predict_taken && (rb_array[rb_head].pc_predict != rb_array[rb_head].pc_taken);

   assign mispredict = direct_mispredict || pc_mispredict;
   
     
   always@(*) begin
      pc_resolved = 32'h0;
      if (direct_mispredict) begin
	 if (rb_array[rb_head].predict_taken) begin
	    pc_resolved = rb_array[rb_head].pc4;
	 end
	 else begin
	    pc_resolved = rb_array[rb_head].pc_taken;
	 end
      end
      else if (pc_mispredict) begin
	 pc_resolved = rb_array[rb_head].pc_taken;
      end
      else begin
	 pc_resolved =rb_array[rb_head].pc_predict;
      end
   end
   
   
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
         rb_tail_ext <= 5'h0;
         for ( int i = 0; i < $size(rb_array) ; i++) begin
            rb_array[i] <= {$size(rbStruct){1'b0}};
         end
      end
      // branch mispredicted
      else if (mispredict) begin 
         for ( int i = rb_head; i < rb_tail + (rb_tail_ext[4] ^ rb_head_ext[4] ? 16:0) ; i++) begin
            rb_array[i%16] <= {$size(rbStruct){1'b0}}; //flush
         end
	 rb_head_ext <= rb_tail_ext;
      end
      // update rob entry
      else begin
         //new entry
         if (struct_avail && inst_valid && inst_type != `EMPTY) begin
	    if (!(rb_tail_ext[4] ^ rb_head_ext[4] && rb_tail_ext[3:0] == rb_head_ext[3:0])) begin
               rb_tail_ext <= rb_tail_ext + 1;
	    end
            rb_array[rb_tail].inst_type <= inst_type;
            rb_array[rb_tail].pc4 <= pc4;
            rb_array[rb_tail].bsy <= 1'b1;
            rb_array[rb_tail].rdy <= 1'b0;
	    rb_array[rb_tail].pc_predict <= btb_pc_predict_dly;
	    rb_array[rb_tail].pc_taken <= seimm_sl2 + pc4;
            case(inst_type)
              `ALU: begin
                 rb_array[rb_tail].dest <= rd;
              end
              `LOAD: begin
                 rb_array[rb_tail].dest <= rt;
              end
              `BRANCH: begin
                 rb_array[rb_tail].predict_taken <= direct_predict_dly;
              end
              default: begin
                 rb_array[rb_tail].dest <= 0;
              end
            endcase 
         end 
         //CDB update    //fixme: consider result from AGU to update dest field
         if (cdb_valid && rb_array[cdb_tag].bsy) begin  
            rb_array[cdb_tag].value = cdb_data;
            rb_array[cdb_tag].rdy = 1'b1;
         end
      end //
   end // always @ (posedge clk, negedge rst)


   
   
   assign direct_resolved = direct_mispredict ? ~rb_array[rb_head].predict_taken: rb_array[rb_head].predict_taken;
   assign branch_commit = rb_array[rb_head].rdy && rb_array[rb_head].inst_type == `BRANCH;
   assign pc_head = rb_array[rb_head].pc4 - 4;
   assign pc_branch = pc4_undly -4;
   
   b_predictor u_b_predictor (//input
			      .clk(clk),
			      .rst(rst),
			      .direct_mispredict(direct_mispredict),
			      .direct_resolved(direct_resolved),
			      .branch_commit(branch_commit),
			      .pc_head(pc_head),
			      .pc_branch(pc_branch),
			      .pc_resolved(pc_resolved),

			      //output
			      .branch_valid(branch_valid),
			      .btb_pc_predict(btb_pc_predict),
			      .direct_predict(direct_predict)
			      );

  // assign direct_predict = 1'b1;

   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 btb_pc_predict_dly <= 32'h0;
	 direct_predict_dly <= 1'b0;
      end
      else begin
	 btb_pc_predict_dly <= btb_pc_predict;
	 direct_predict_dly <= direct_predict;
      end
   end
   
   

   always @(*) begin
      if (branch_valid) begin
           predict_taken = direct_predict;
           predict_valid = 1;
           pc_predict = btb_pc_predict;  // fixme:pc_predict should be rb attribution, in case of nested branch
      end
      else begin
         predict_valid = 0;
	 predict_taken = 0;
	 pc_predict = 32'h0;
      end
   end
   
   //commit control signals 
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
         rb_head_ext <= 5'h0;
         commit_dest <= 7'h00;
         commit_value <= 32'h0000;
         commit_mem_valid <= 1'b0;
         commit_reg_valid <= 1'b0;       
      end
      else  begin

         // set commit output
         case(rb_array[rb_head].inst_type)
           `ALU, `LOAD:begin
	      if (rb_array[rb_head].rdy) begin
		 commit_reg_valid <= 1'b1;
		 commit_mem_valid <= 1'b0;
		 commit_value <= rb_array[rb_head].value;
		 commit_dest <= rb_array[rb_head].dest;
		 rb_head_ext <= rb_head_ext + 1;
		 rb_array[rb_head] <= {$size(rbStruct){1'b0}};
	      end
	      else begin
		 commit_reg_valid <= 1'b0;
		 commit_mem_valid <= 1'b0;       
	      end  
           end
           `STORE: begin
	      if (store_array[store_head].rdy_s2) begin
		 commit_reg_valid <= 1'b0;
		 commit_mem_valid <= 1'b1;
		 commit_value <= store_array[store_head].s2;
		 commit_dest <= store_array[store_head].A;
		 rb_head_ext <= rb_head_ext + 1;
		 rb_array[rb_head] <= {$size(rbStruct){1'b0}};
		 store_head <= store_head + 1;
		 store_array[store_head].bsy <= 0;
	      end
	      else begin
		 commit_reg_valid <= 1'b0;
		 commit_mem_valid <= 1'b0;       
	      end  	      
           end // case: `STORE	      
       
           `BRANCH: begin
	      if (rb_array[rb_head].rdy) begin
		 commit_reg_valid <= 1'b0;
		 commit_mem_valid <= 1'b0;
		 rb_head_ext <= rb_head_ext + 1;
		 rb_array[rb_head] <= {$size(rbStruct){1'b0}};;
	      end
	      else begin
		 commit_reg_valid <= 1'b0;
		 commit_mem_valid <= 1'b0;       
	      end  	      
           end // case: `BRANCH

	   default: begin
	      commit_reg_valid <= 1'b0;
	      commit_mem_valid <= 1'b0; 
	   end
         endcase // case (rb_array[rb_head].inst_type)
      end // if (rb_array[rb_head].rdy)
   end // always @ (posedge clk, negedge rst)



   // update reg status
   always @(*) begin
      wr_regs_en = 1'b0;
      wr_regs_tag = 0;
      if (inst_valid) begin
         case (inst_type)
           `ALU: begin
              wr_regs_en = 1'b1;
              wr_regs_tag = rd;
           end
           `LOAD: begin
              wr_regs_en = 1'b1;
              wr_regs_tag = rt;
           end
           default: begin
              wr_regs_en = 1'b0;
              wr_regs_tag = 0;
           end
         endcase // case (inst_type)
      end // if (inst_valid)
   end // always @ (posedge clk, negedge rst)
   
   assign wr_regs_rb_tag = rb_tail;


   //-----------------------------------------------------------------
   //                 Reservation Stations (rs)
   //-----------------------------------------------------------------

   rs u_rs1 (
	     .rb_tag1_rdy		(rb_array[rd_rb_tag1].rdy),
	     .rb_tag1_value		(rb_array[rd_rb_tag1].value),
	     .rb_tag2_rdy		(rb_array[rd_rb_tag2].rdy),
	     .rb_tag2_value		(rb_array[rd_rb_tag2].value),
	     .cdb_tag_alu               (cdb_tag0),
	     .cdb_grant			(cdb_grant0),
	     /*AUTOINST*/
	     // Outputs
	     .rs_avail			(rs_avail),
	     .alusrc1			(alusrc1[31:0]),
	     .alusrc2			(alusrc2[31:0]),
	     .alufunct			(alufunct[5:0]),
	     .aluopcode			(aluopcode[5:0]),
	     .rs_req			(rs_req[3:0]),
	     // Inputs
	     .rst			(rst),
	     .clk			(clk),
	     .inst_type			(inst_type[2:0]),
	     .rs			(rs[4:0]),
	     .rt			(rt[4:0]),
	     .rd			(rd[4:0]),
	     .imm			(imm[15:0]),
	     .seimm			(seimm[31:0]),
	     .seimm_sl2			(seimm_sl2[31:0]),
	     .pc4			(pc4[31:0]),
	     .funct			(funct[5:0]),
	     .opcode			(opcode[5:0]),
	     .reg_rs			(reg_rs[31:0]),
	     .reg_rt			(reg_rt[31:0]),
	     .rd_rb_tag1		(rd_rb_tag1[3:0]),
	     .rd_bsy1			(rd_bsy1),
	     .rd_rb_tag2		(rd_rb_tag2[3:0]),
	     .rd_bsy2			(rd_bsy2),
	     .rb_tail			(rb_tail[3:0]),
	     .mispredict		(mispredict),
	     .inst_valid		(inst_valid),
	     .struct_avail		(struct_avail),
	     .cdb_valid			(cdb_valid),
	     .cdb_data			(cdb_data[31:0]),
	     .cdb_tag			(cdb_tag[3:0]),
	     .commit_reg_valid		(commit_reg_valid),
	     .commit_dest		(commit_dest[6:0]),
	     .commit_value		(commit_value[31:0]));
	     
   
   //-----------------------------------------------------------------
   //                 Load-Store Unit (lsu)
   //-----------------------------------------------------------------  

   typedef struct packed{
      bit [2:0]   inst_type;
      bit [31:0]  s1;
      bit [31:0]  s2;
      bit [31:0]  A;
      bit 	  rdy_A;
      bit [3:0]   rb_tag;
      bit         rdy_s1;
      bit         rdy_s2;
      bit         bsy;
      bit [31:0]  result;
      bit         rdy_result;
      bit [5:0]   funct;
      bit [5:0]   opcode;
      bit 	  rdy_s1_dly;
      bit 	  lsu_addr_done;
      
   } lsuStruct;
   
   typedef struct packed{
      bit [2:0]   inst_type;
      bit [31:0]  s1;
      bit [31:0]  s2;
      bit [31:0]  A;
      bit 	  rdy_A;
      bit [3:0]   rb_tag;
      bit         rdy_s1;
      bit         rdy_s2;
      bit         bsy;
      bit [31:0]  result;
      bit         rdy_result;
      bit [5:0]   funct;
      bit [5:0]   opcode;
   } storeStruct;
   
   lsuStruct lsu_array [`RS_WIDTH-1:0];
   storeStruct store_array [`RS_WIDTH-1:0];
   
   assign lsu_bsy = lsu_array[0].bsy & lsu_array[1].bsy & lsu_array[2].bsy & lsu_array[3].bsy;
   assign lsu_avail = ~lsu_bsy;   
 
   always @(posedge clk, negedge rst) begin
      if(!rst) begin
	 lsu_head <= 2'h0;
	 lsu_tail <= 2'h0;
         for ( int i = 0; i < $size(lsu_array) ; i++) begin
            lsu_array[i] <= {$size(lsuStruct){1'b0}};
         end	 
      end
      else if (mispredict) begin
	 lsu_head <= 2'h0;
	 lsu_tail <= 2'h0;
         for ( int i = 0; i < $size(lsu_array) ; i++) begin
            lsu_array[i] <= {$size(lsuStruct){1'b0}};
         end
      end	 
      else begin
	 if (inst_valid && struct_avail &&  (inst_type == `STORE || inst_type == `LOAD)) begin
            lsu_tail <= lsu_tail + 1;	    
            lsu_array[lsu_tail].inst_type <= inst_type;
            lsu_array[lsu_tail].bsy <= 1'b1;
            lsu_array[lsu_tail].rb_tag <= rb_tail;
            lsu_array[lsu_tail].A <= seimm;  
            if (rd_bsy1) begin
               if (rb_array[rd_rb_tag1].rdy) begin
                  lsu_array[lsu_tail].s1 <= rb_array[rd_rb_tag1].value;
                  lsu_array[lsu_tail].rdy_s1 <= 1'b1;
               end
               else begin
		  //concurrent check cdb, inserting LSU and broadcasting may happen at the same time
		  if (cdb_valid && rd_rb_tag1 == cdb_tag) begin
		     lsu_array[lsu_tail].rdy_s1 <= 1'b1;
		     lsu_array[lsu_tail].s1 <= cdb_data;
		  end
		  else begin
		     lsu_array[lsu_tail].s1 <= rd_rb_tag1;
		     lsu_array[lsu_tail].rdy_s1 <= 1'b0;
		  end
               end
            end
            else begin
               lsu_array[lsu_tail].s1 <= reg_rs;
               lsu_array[lsu_tail].rdy_s1 <= 1'b1;
            end // else: !if(rd_bsy1)

	    // LOAD don't need to read s2, but doesn't hurt
            if (rd_bsy2) begin
               if (rb_array[rd_rb_tag2].rdy) begin
                  lsu_array[lsu_tail].s2 <= rb_array[rd_rb_tag2].value;
                  lsu_array[lsu_tail].rdy_s2 <= 1'b1;
               end
               else begin
		  //concurrent check cdb, inserting LSU and broadcasting may happen at the same time
		  if (cdb_valid && rd_rb_tag2 == cdb_tag) begin
		     lsu_array[lsu_tail].rdy_s2 <= 1'b1;
		     lsu_array[lsu_tail].s2 <= cdb_data;
		  end
		  else begin
		     lsu_array[lsu_tail].s2 <= rd_rb_tag2;
		     lsu_array[lsu_tail].rdy_s2 <= 1'b0;
		  end
               end
            end
            else begin
               lsu_array[lsu_tail].s2 <= reg_rt;
               lsu_array[lsu_tail].rdy_s2 <= 1'b1;
            end 
	 end // if (inst_valid && (inst_type == `STORE || inst_type == `LOAD))

	 //when address complete
	 if (lsu_addr_done) begin
	    lsu_array[lsu_head].A <= lsu_addr;
	    lsu_array[lsu_head].rdy_A <= 1'b1;
	 end

	 // when load complete, update rb
	 if (mem_done) begin
	    lsu_array[lsu_head].rdy_result <= 1'b1;
	    lsu_array[lsu_head].result <= mem_value;
	    rb_array[lsu_array[lsu_head].rb_tag].rdy <= 1'b1;
	    rb_array[lsu_array[lsu_head].rb_tag].value <= mem_value;
	 end

	 //lsu head retire
	 // store only need address rdy to go to store buffer; load needs result rdy and cdb grant
	 if ((lsu_array[lsu_head].inst_type == `LOAD && lsu_array[lsu_head].rdy_result && cdb_grant1) ||
	     (lsu_array[lsu_head].inst_type == `STORE && lsu_array[lsu_head].rdy_A)) begin
	    lsu_head <= lsu_head + 1;
	    lsu_array[lsu_head].bsy <= 1'b0;
	    lsu_array[lsu_head].rdy_s1 <= 1'b0;
	    lsu_array[lsu_head].rdy_s2 <= 1'b0;
	    lsu_array[lsu_head].rdy_result <= 1'b0;
	    lsu_array[lsu_head].rdy_A <= 1'b0;
	 end
      end // else: !if(cdb_valid)
   end // always @ (posedge clk, negedge rst)

   logic cdb_req1;
   logic [31:0] cdb_data1;
   logic [3:0] cdb_tag1;
   
   assign cdb_req1 = (lsu_array[lsu_head].inst_type == `LOAD) && lsu_array[lsu_head].rdy_result;
   assign cdb_data1 = lsu_array[lsu_head].result;
   assign cdb_tag1 = lsu_array[lsu_head].rb_tag;
   

   
   
   
   always @(*) begin
      lsu_s1 = 0;
      lsu_A  = 0;      
      if ( lsu_array[lsu_head].rdy_s1) begin
         //output s1 and A to AGU
         lsu_s1 = lsu_array[lsu_head].s1;
         lsu_A  = lsu_array[lsu_head].A;
      end
   end
   

   always @(posedge clk, negedge rst) begin
      if (!rst) begin
         rdy_s1_dly <= 1'b0;
      end
      else begin
         lsu_array[lsu_head].rdy_s1_dly <= lsu_array[lsu_head].rdy_s1;
      end
   end
   
   //Assume AGU calculate address immediately
   assign lsu_addr_done = ~lsu_array[lsu_head].rdy_s1_dly & lsu_array[lsu_head].rdy_s1;
  

   // don't consider mem port conflict
   //logic  mem_lock;


   //-----------------------------------------------------------------
   //                 Store-Queue
   //----------------------------------------------------------------- 
   // 
   // foreach load in lsu head, check addr with active addr in store buffer, 
   // if not any match, read from mem and then update corresponding rb and write on CDB; 
   // otherwise, copy matched store entry's s2 value and ready to this.entry's s2 
   // (could be a tag if not ready, which means also need to monitor CDB) and ready
   
   integer j;
   logic   load_addr_safe;
   
   // insert store_array
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 store_tail <= 0;
	 store_head <= 0;
         for ( int i = 0; i < $size(store_array) ; i++) begin
            store_array[i] <= {$size(storeStruct){1'b0}};
         end
	 load_addr_safe <= 1'b0;
      end
      else if (mispredict) begin
	 store_tail <= 0;
	 store_head <= 0;	 
         for ( int i = 0; i < $size(store_array) ; i++) begin
            store_array[i] <= {$size(storeStruct){1'b0}};
         end
	 load_addr_safe <= 1'b0;
      end
      else begin 
	if (lsu_addr_done) begin
           case (lsu_array[lsu_head].inst_type)
             `LOAD: begin
		j = -1;
		for (int i = store_head; i < store_tail; i = i + 1) begin
                   if(lsu_addr == store_array[i].A) begin
                      j = i;
                   end
		end
		// no addr match
		if ( j == -1) begin 
                   load_addr_safe <= 1'b1;
		end
		else begin
		   load_addr_safe <= 1'b0;
		   //concurrent check cdb
		   if (cdb_valid && !store_array[j].rdy_s2 && store_array[j].s2 == cdb_tag) begin
		      lsu_array[lsu_head].rdy_result <= 1'b1;
		      lsu_array[lsu_head].result <= cdb_data;
		   end
		   else begin
                      lsu_array[lsu_head].result <= store_array[j].s2;
                      lsu_array[lsu_head].rdy_result <= store_array[j].rdy_s2;
		   end
		end
             end

             `STORE: begin
		load_addr_safe <= 1'b0;
		store_tail <= store_tail + 1;
		store_array[store_tail].A <= lsu_addr;
		store_array[store_tail].s2 <= lsu_array[lsu_head].s2;
		store_array[store_tail].rdy_s2 <= lsu_array[lsu_head].rdy_s2;
		store_array[store_tail].bsy <= 1'b1;            
             end
         endcase // case (lsu_array[lsu_head].inst_type)
	end // if (lsu_addr_done)
	else begin
	   load_addr_safe <= 1'b0;
	end // else: !if(mispredict)
	 
	 //CDB to update store buffer and load
	 if (cdb_valid) begin
	    for (int i = store_head; i < store_tail; i++) begin
	       if (store_array[i].bsy && !store_array[i].rdy_s2 && store_array[i].s2 == cdb_tag) begin
		  store_array[i].rdy_s2 <= 1'b1;
		  store_array[i].s2 <= cdb_data;
	       end
	    end	       
	    if (lsu_array[lsu_head].bsy && !lsu_array[lsu_head].rdy_result && 
		lsu_array[lsu_head].result == cdb_tag) begin
	       lsu_array[lsu_head].rdy_result <= 1'b1;
	       lsu_array[lsu_head].result <= cdb_data;
	    end
	 end
      end // else: !if(mispredict)
   end // always @ (posedge clk, negedge rst)

   logic load_addr_safe_dly;
   
/* -----\/----- EXCLUDED -----\/-----
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 load_addr_safe_dly <= 1'b0;
      end
      else begin
	 load_addr_safe_dly <= load_addr_safe;
      end
   end

   assign mem_done = load_addr_safe && ~load_addr_safe_dly;
 -----/\----- EXCLUDED -----/\----- */

   assign mem_done = load_addr_safe;
   
   always @(*) begin
      if (mem_done) begin
         mem_addr = lsu_addr;
      end
      else begin
         mem_addr = 0;
      end
   end // always @ begin


   // CDB
   cdb u_cdb (
              //input
	      .clk(clk),
	      .rst(rst),
              .cdb_req0(|rs_req),
              .cdb_data0(alu_out),
              .cdb_tag0(cdb_tag0),
              .cdb_req1(cdb_req1),
              .cdb_data1(cdb_data1),
              .cdb_tag1(cdb_tag1),
              //output
              .cdb_grant0(cdb_grant0),
              .cdb_grant1(cdb_grant1),
              .cdb_data(cdb_data),
              .cdb_tag(cdb_tag),
              .cdb_valid(cdb_valid)	      
              );
   
endmodule // rb

`endif //  `ifndef _rb

// Emacs Verilog AUTOs
// Local Variables:
// verilog-library-directories:("." "../verilog")
// End:
