`ifndef _rb
 `define _rb 

 `include "arbiter.v"
 `include "cdb.v"
 `include "b_predictor.v"

module rb (
           input 	       rst,
           input 	       clk,
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


           //output          avail_rb, //if there is any empty entry in rb
           //output          avail_rs, //if there is any empty entry in rs
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

   //-----------------------------------------------------------------
   //                 Reorder Buffer (rb)
   //-----------------------------------------------------------------  

   logic                       cdb_valid;
   logic [31:0]                cdb_data;
   logic [3:0]                 cdb_tag; //tag
   logic 		       cdb_grant0;
   logic 		       cdb_grant1;
   
   logic                       rb_avail;
   logic                       rs_avail;
   
   
   logic                       inst_valid;
   logic [`RS_WIDTH-1 : 0]     rs_grant;
   logic [3:0] 		       cdb_tag0;
   logic 		       lsu_bsy;
   logic [3+1:0] 	       rb_head_ext, rb_tail_ext; //1 bit overhead to detect full
   logic [3:0] 		       rb_head, rb_tail;
   logic                       rb_bsy;
   logic 		       rdy_s1_dly;
   logic [`RS_WIDTH-1 : 0]     rs_req;
   
   logic [`RS_TAG_WIDTH-1:0]   lsu_tail; //point to next empty entry
   logic [`RS_TAG_WIDTH-1:0]   lsu_head; //point to queue head

   logic [`RS_TAG_WIDTH-1:0]   store_tail; 
   logic [`RS_TAG_WIDTH-1:0]   store_head; 
   logic [`RS_TAG_WIDTH-1:0]   load_tail; 
   logic [`RS_TAG_WIDTH-1:0]   load_head; 
   logic 		       rs_bsy;
   logic [`RS_TAG_WIDTH-1:0]   rs_tail; //point to next empty entry
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
   
   
   assign inst_valid = (inst_type == `LOAD || inst_type == `STORE) ? rb_avail & lsu_avail : rb_avail & rs_avail; 
   assign stall = ~inst_valid;
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
         if (inst_valid) begin
	    if (!(rb_tail_ext[4] ^ rb_head_ext[4] && rb_tail_ext[3:0] == rb_head_ext[3:0])) begin
               rb_tail_ext <= rb_tail_ext + 1;
	    end
            rb_array[rb_tail].inst_type <= inst_type;
            rb_array[rb_tail].pc4 <= pc4;
            rb_array[rb_tail].bsy <= 1'b1;
            rb_array[rb_tail].rdy <= 1'b0;
	    rb_array[rb_tail].pc_predict <= 32'h14;
            case(inst_type)
              `ALU: begin
                 rb_array[rb_tail].dest <= rd;
              end
              `LOAD: begin
                 rb_array[rb_tail].dest <= rt;
              end
              `BRANCH: begin
                 rb_array[rb_tail].predict_taken <= direct_predict;
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
   assign pc_branch = pc4 -4;
   
   b_predictor u_b_predictor (.clk(clk),
			      .rst(rst),
			      .direct_mispredict(direct_mispredict),
			      .direct_resolved(direct_resolved),
			      .branch_commit(branch_commit),
			      .pc_head(pc_head),
			      .pc_branch(pc_branch),
			      .branch_valid(predict_valid),

			      .direct_predict(direct_predict)
			      );

  // assign direct_predict = 1'b1;
   
   

   always @(*) begin
      case (inst_type)
        `BRANCH: begin
           predict_taken = direct_predict;
           predict_valid = 1;
           pc_predict = 32'h14;  // fixme:pc_predict should be rb attribution, in case of nested branch
        end
        default: begin
           predict_valid = 0;
	   predict_taken = 0;
	   pc_predict = 32'h0;
        end
      endcase // case (inst_type)
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
           end
         endcase // case (rb_array[rb_head].inst_type)
      end // if (rb_array[rb_head].rdy)
   end // always @ (posedge clk, negedge rst)

   //-----------------------------------------------------------------
   //                 Reservation Stations (rs)
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
   } rsStruct;
   rsStruct rs_array [`RS_WIDTH-1:0];
   

   assign rs_bsy = rs_array[0].bsy & rs_array[1].bsy & rs_array[2].bsy & rs_array[3].bsy;
   assign rs_avail = ~rs_bsy;   
   
   
   // priority encoder
   always @(*) begin
      if (rs_avail == 1'b1) begin
         for (int i = 0; i < $size(rs_array); i++) begin
            if (rs_array[i].bsy == 1'b0) begin
               rs_tail = i;
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
      //misprediction, flush
      else if (mispredict) begin 
         for ( int i = 0; i < $size(rs_array) ; i++) begin
            rs_array[i] <= {$size(rsStruct){1'b0}};
         end
      end
      else begin
         if (inst_valid && (inst_type == `ALU || inst_type == `BRANCH)) begin
            rs_array[rs_tail].inst_type <= inst_type;
            rs_array[rs_tail].bsy <= 1'b1;
            rs_array[rs_tail].rb_tag <= rb_tail;
            rs_array[rs_tail].A <= imm;      // todo: check if need sign extend
	    rb_array[rb_tail].pc_taken <= seimm_sl2 + pc4;
            rs_array[rs_tail].funct <= funct;
            rs_array[rs_tail].opcode <= opcode;
            
            if (rd_bsy1) begin // if busy in RegisterStatus, which means in ROB
               if (rb_array[rd_rb_tag1].rdy) begin
                  rs_array[rs_tail].s1 <= rb_array[rd_rb_tag1].value;
                  rs_array[rs_tail].rdy_s1 <= 1'b1;
               end
               else begin
		  //concurrent check cdb, inserting RS and broadcasting may happen at the same time
		  if (cdb_valid && rd_rb_tag1 == cdb_tag) begin
		     rs_array[rs_tail].rdy_s1 <= 1'b1;
		     rs_array[rs_tail].s1 <= cdb_data;
		  end
		  //concurrent check commit, inserting RS and commit may happen at the same time;
		  //cdb broacast has higher priority than commit, since cdb gets latest value
		  else if (commit_reg_valid && rs == commit_dest) begin
		     rs_array[rs_tail].rdy_s1 <= 1'b1;
		     rs_array[rs_tail].s1 <= commit_value;
		  end
		  else begin
		     rs_array[rs_tail].s1 <= rd_rb_tag1;
		     rs_array[rs_tail].rdy_s1 <= 1'b0;
		  end
               end
            end
            else begin
               rs_array[rs_tail].s1 <= reg_rs;
               rs_array[rs_tail].rdy_s1 <= 1'b1;
            end // else: !if(rd_bsy1)

            if (rd_bsy2) begin
               if (rb_array[rd_rb_tag2].rdy) begin
                  rs_array[rs_tail].s2 <= rb_array[rd_rb_tag2].value;
                  rs_array[rs_tail].rdy_s2 <= 1'b1;
               end
               else begin
		  //concurrent check cdb, inserting RS and broadcasting may happen at the same time
		  if (cdb_valid && rd_rb_tag2 == cdb_tag) begin
		     rs_array[rs_tail].rdy_s2 <= 1'b1;
		     rs_array[rs_tail].s2 <= cdb_data;
		  end
		  //concurrent check commit, inserting RS and commit may happen at the same time;
		  //cdb broacast has higher priority than commit, since cdb gets latest value
		  else if (commit_reg_valid && rt == commit_dest) begin
		     rs_array[rs_tail].rdy_s2 <= 1'b1;
		     rs_array[rs_tail].s2 <= commit_value;
		  end		  
		  else begin
		     rs_array[rs_tail].s2 <= rd_rb_tag2;
		     rs_array[rs_tail].rdy_s2 <= 1'b0;
		  end
               end
            end
            else begin
               rs_array[rs_tail].s2 <= reg_rt;
               rs_array[rs_tail].rdy_s2 <= 1'b1;
            end             
	 end // if (inst_valid && (inst_type == `ALU || inst_type == `BRANCH))
      
	 //cdb tag compare with rs
	 if (cdb_valid) begin
            for (int i = 0; i < $size(rs_array) ; i++) begin
               if (rs_array[i].bsy && !rs_array[i].rdy_s1 && (rs_array[i].s1 == cdb_tag)) begin
		  rs_array[i].rdy_s1 <= 1'b1;
		  rs_array[i].s1 <= cdb_data;
               end
               if (rs_array[i].bsy && !rs_array[i].rdy_s2 && (rs_array[i].s2 == cdb_tag)) begin
		  rs_array[i].rdy_s2 <= 1'b1;
		  rs_array[i].s2 <= cdb_data;
               end             
            end
	 end // if (cdb_valid)   
      end // else: !if(rb_array[rb_head].rdy && rb_array[rb_head].inst_type == `BRANCH &&... 
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


   
   assign rs_req = {rs_array[3].rdy_s1 & rs_array[3].rdy_s2 & rs_array[3].bsy,
                    rs_array[2].rdy_s1 & rs_array[2].rdy_s2 & rs_array[2].bsy,
                    rs_array[1].rdy_s1 & rs_array[1].rdy_s2 & rs_array[1].bsy,
                    rs_array[0].rdy_s1 & rs_array[0].rdy_s2 & rs_array[0].bsy
                    };
   
   //clear rs entry after issue
   always @(posedge clk) begin
      if (cdb_grant0) begin
	 case (rs_grant)
           4'b0001: begin
              rs_array[0] <= {$size(rsStruct){1'b0}};
           end
           4'b0010: begin
              rs_array[1] <= {$size(rsStruct){1'b0}};
           end
           4'b0100: begin
              rs_array[2] <= {$size(rsStruct){1'b0}};
           end     
           4'b1000: begin
              rs_array[3] <= {$size(rsStruct){1'b0}};
           end         
	 endcase // case rs_grant
      end
   end
   
   arbiter #(.WIDTH(`RS_WIDTH)) u_arbiter_rs (
                                              .req (rs_req),
					      .clk(clk),
					      .rst(rst),
                                              .enable (1'b1),  // fixme: connect to function unit avail, for now the ALU only take 1 clock cycle
                                              .grant (rs_grant),
                                              .anyreq()
                                              );
   // issue to ALU && generate CDB broadcast tag
   always @(*) begin
      case (rs_grant)
        4'b0001: begin
           alusrc1 = rs_array[0].s1;
           alusrc2 = rs_array[0].s2;
           alufunct = rs_array[0].funct;
           aluopcode = rs_array[0].opcode;
           cdb_tag0 = rs_array[0].rb_tag;
        end
        4'b0010: begin
           alusrc1 = rs_array[1].s1;
           alusrc2 = rs_array[1].s2;
           alufunct = rs_array[1].funct;
           aluopcode = rs_array[1].opcode;
           cdb_tag0 = rs_array[1].rb_tag;
        end
        4'b0100: begin
           alusrc1 = rs_array[2].s1;
           alusrc2 = rs_array[2].s2;
           alufunct = rs_array[2].funct;
           aluopcode = rs_array[2].opcode;
           cdb_tag0 = rs_array[2].rb_tag;
        end     
        4'b1000: begin
           alusrc1 = rs_array[3].s1;
           alusrc2 = rs_array[3].s2;
           alufunct = rs_array[3].funct;
           aluopcode = rs_array[3].opcode;
           cdb_tag0 = rs_array[3].rb_tag;
        end
	default: begin
           alusrc1 = 0;
           alusrc2 = 0;
           alufunct = 0;
           aluopcode = 0;
           cdb_tag0 = 0;
	end	   
      endcase // case (rs_grant)
   end // always @ begin


   
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
   
   
   lsuStruct lsu_array [`RS_WIDTH-1:0];
   rsStruct store_array [`RS_WIDTH-1:0];
   rsStruct load_array [`RS_WIDTH-1:0];


   
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
	 if (inst_valid && (inst_type == `STORE || inst_type == `LOAD)) begin
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
         for ( int i = 0; i < $size(rs_array) ; i++) begin
            store_array[i] <= {$size(rsStruct){1'b0}};
         end
	 load_addr_safe <= 1'b0;
      end
      else if (mispredict) begin
	 store_tail <= 0;
	 store_head <= 0;	 
         for ( int i = 0; i < $size(rs_array) ; i++) begin
            store_array[i] <= {$size(rsStruct){1'b0}};
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

`endif
