`ifndef _rs
 `define _rs

module rs (
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
	   input [31:0]        reg_rs, //return from register memory
           input [31:0]        reg_rt,

           input [3:0] 	       rd_rb_tag1, // return from RegisterStatus
           input 	       rd_bsy1,
           input [3:0] 	       rd_rb_tag2,
           input 	       rd_bsy2,
	   
	   input [3:0] 	       rb_tail,
	   input 	       rb_tag1_rdy,
	   input [31:0]        rb_tag1_value,
	   input 	       rb_tag2_rdy,
	   input [31:0]        rb_tag2_value,

	   input 	       mispredict,
	   input 	       inst_valid, // when to insert a new entry
	   input               struct_avail,
	   input 	       cdb_valid,
	   input [31:0]        cdb_data,
	   input [3:0] 	       cdb_tag, //tag
	   input 	       cdb_grant,
	   output logic [3:0]  cdb_tag_alu,
	   
	   input 	       commit_reg_valid,
	   input logic [6:0]   commit_dest,
	   input logic [31:0]  commit_value,
	   
	   output logic        rs_avail, //if there is any empty entry
	   output logic [31:0] alusrc1,
           output logic [31:0] alusrc2,
           output logic [5:0]  alufunct,
           output logic [5:0]  aluopcode,
	   output logic [3: 0] rs_req
	   );
 `define RS_WIDTH 4
 `define RS_TAG_WIDTH 2 // log2 of RS_WIDTH

 `define ALU 3'h0
 `define LOAD 3'h1
 `define STORE 3'h2
 `define BRANCH 3'h3
 `define EMPTY 3'h4

   logic [`RS_WIDTH-1 : 0]     rs_grant;
   logic 		       rs_bsy;
   logic [`RS_TAG_WIDTH-1:0]   rs_tail; //point to next empty entry

   
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
         if (inst_valid && struct_avail && (inst_type == `ALU || inst_type == `BRANCH)) begin
            rs_array[rs_tail].inst_type <= inst_type;
            rs_array[rs_tail].bsy <= 1'b1;
            rs_array[rs_tail].rb_tag <= rb_tail;
            rs_array[rs_tail].A <= imm;      // todo: check if need sign extend
            rs_array[rs_tail].funct <= funct;
            rs_array[rs_tail].opcode <= opcode;
            
            if (rd_bsy1) begin // if busy in RegisterStatus, which means in ROB
               if (rb_tag1_rdy) begin
                  rs_array[rs_tail].s1 <= rb_tag1_value;
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
               if (rb_tag2_rdy) begin
                  rs_array[rs_tail].s2 <= rb_tag2_value;
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

       
   
   
   assign rs_req = {rs_array[3].rdy_s1 & rs_array[3].rdy_s2 & rs_array[3].bsy,
                    rs_array[2].rdy_s1 & rs_array[2].rdy_s2 & rs_array[2].bsy,
                    rs_array[1].rdy_s1 & rs_array[1].rdy_s2 & rs_array[1].bsy,
                    rs_array[0].rdy_s1 & rs_array[0].rdy_s2 & rs_array[0].bsy
                    };
   
   //clear rs entry after issue
   always @(posedge clk) begin
      if (cdb_grant) begin
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
           cdb_tag_alu = rs_array[0].rb_tag;
        end
        4'b0010: begin
           alusrc1 = rs_array[1].s1;
           alusrc2 = rs_array[1].s2;
           alufunct = rs_array[1].funct;
           aluopcode = rs_array[1].opcode;
           cdb_tag_alu = rs_array[1].rb_tag;
        end
        4'b0100: begin
           alusrc1 = rs_array[2].s1;
           alusrc2 = rs_array[2].s2;
           alufunct = rs_array[2].funct;
           aluopcode = rs_array[2].opcode;
           cdb_tag_alu = rs_array[2].rb_tag;
        end     
        4'b1000: begin
           alusrc1 = rs_array[3].s1;
           alusrc2 = rs_array[3].s2;
           alufunct = rs_array[3].funct;
           aluopcode = rs_array[3].opcode;
           cdb_tag_alu = rs_array[3].rb_tag;
        end
	default: begin
           alusrc1 = 0;
           alusrc2 = 0;
           alufunct = 0;
           aluopcode = 0;
           cdb_tag_alu = 0;
	end	   
      endcase // case (rs_grant)
   end // always @ begin

   
endmodule // rs
`endif //  `ifndef _rs
