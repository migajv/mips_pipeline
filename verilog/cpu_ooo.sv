/*
 * cpu_ooo. - out of order MIPS CPU.
 *
 */

`include "regr.v"
`include "im.v"
`include "regm.v"
`include "control.v"
`include "alu.v"
`include "alu_control.v"
`include "dm.v"
`include "rb.v"
`include "regstatus.v"
`include "iq.v"

`ifndef DEBUG_CPU_STAGES
 `define DEBUG_CPU_STAGES 0
`endif

 `define ALU 3'h0
 `define LOAD 3'h1
 `define STORE 3'h2
 `define BRANCH 3'h3
 `define EMPTY 3'h4
module cpu_ooo(
           input wire 	     clk,
	   input wire        rst,
           input wire [31:0] im_add,
           input wire [31:0] im_data,
           input wire 	     im_en,
           input wire 	     im_rd_wr,
	   output reg [31:0] pc
	   /*AUTOARG*/);


   //
/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
logic [6:0]		commit_dest;		// From u_rb of rb.v
logic			commit_mem_valid;	// From u_rb of rb.v
logic			commit_reg_valid;	// From u_rb of rb.v
logic [31:0]		commit_value;		// From u_rb of rb.v
logic [31:0]		inst1;			// From im1 of im.v
logic [31:0]		inst1_out;		// From u_iq of iq.v
logic			inst1_out_valid;	// From u_iq of iq.v
logic			inst1_valid;		// From im1 of im.v
logic [31:0]		inst2_out;		// From u_iq of iq.v
logic			inst2_out_valid;	// From u_iq of iq.v
logic			iq_empty;		// From u_iq of iq.v
logic [31:0]		lsu_A;			// From u_rb of rb.v
logic [31:0]		lsu_s1;			// From u_rb of rb.v
logic [6:0]		mem_addr;		// From u_rb of rb.v
logic			mispredict;		// From u_rb of rb.v
logic			predict_taken;		// From u_rb of rb.v
logic			predict_valid;		// From u_rb of rb.v
wire			rd_bsy1;		// From u_regstatus of regstatus.v
wire			rd_bsy2;		// From u_regstatus of regstatus.v
wire [3:0]		rd_rb_tag1;		// From u_regstatus of regstatus.v
wire [3:0]		rd_rb_tag2;		// From u_regstatus of regstatus.v
logic			wr_regs_en;		// From u_rb of rb.v
logic [3:0]		wr_regs_rb_tag;		// From u_rb of rb.v
logic [4:0]		wr_regs_tag;		// From u_rb of rb.v
// End of automatics
   logic [31:0] 	inst;
   logic 		stall_backend;
   logic 		stall_iq;
   logic [31:0] 	pc4_dly;
   
   wire [31:0] 		reg_rs;
   wire [31:0] 		reg_rt;
   wire [31:0] alu_out;

   wire        zero_s3;
   wire [5:0]  alufunct;
   wire [5:0]  aluopcode;
   wire [31:0] alusrc1;
   wire [31:0] alusrc2;   
   wire [31:0] agusrc_data1;
   wire [31:0] agusrc_data2; 
   wire [31:0] agurslt;
   wire [31:0] lsu_addr;
   wire [31:0] dm_rdata;

   // decode instruction
   wire [5:0]  opcode;
   wire [4:0]  rs;
   wire [4:0]  rt;
   wire [4:0]  rd;
   wire [15:0] imm;
   wire [4:0]  shamt;
   wire [25:0] jimm;  // jump, immediate
   wire [31:0] seimm;  // sign extended immediate
   wire [5:0]  funct;
   wire [31:0] seimm_sl2;
   
   
   parameter NMEM = 20;  // number in instruction memory
   parameter IM_DATA = "im_data.txt";

/* -----\/----- EXCLUDED -----\/-----
   initial begin
      if (`DEBUG_CPU_STAGES) begin
         $display("if_pc,    if_instr, id_regrs, id_regrt, ex_alua,  ex_alub,  ex_aluctl, mem_memdata, mem_memread, mem_memwrite, wb_regdata, wb_regwrite");
         $monitor("%x, %x, %x, %x, %x, %x, %x,         %x,    %x,           %x,            %x,   %x",
                  pc,                           /-* if_pc *-/
                  inst,                 /-* if_instr *-/
                  data1,                        /-* id_regrs *-/
                  data2,                        /-* id_regrt *-/
                  data1_s3,             /-* data1_s3 *-/
                  alusrc_data2, /-* alusrc_data2 *-/
                  aluctl,                       /-* ex_aluctl *-/
                  data2_s4,             /-* mem_memdata *-/
                  memread_s4,           /-* mem_memread *-/
                  memwrite_s4,  /-* mem_memwrite *-/
                  wrdata_s5,            /-* wb_regdata *-/
                  regwrite_s5           /-* wb_regwrite *-/
                  );
      end
   end
 -----/\----- EXCLUDED -----/\----- */

   wire [31:0] pc4;  // PC + 4
   assign pc4 = pc + 4;

   wire         stall;
   wire [31:0] 	pc_resolved ; // generated from AGU(address generation unit) from branch instruction
   wire [31:0] 	pc_predict;
   

   
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 pc <= 32'h0;
      end
      else if (stall_iq) begin
         pc <= pc;
      end
      else if (mispredict) begin
	 pc <= pc_resolved;
      end
      else if (predict_taken && predict_valid) begin
	 pc <= pc_predict;
      end
      else begin
         pc <= pc4;
      end
   end

   //delay pc4 to pass to rb, since all other decode information has 1 cycle delay due to the iq
   always @(posedge clk, negedge rst) begin
      if (!rst) begin
	 pc4_dly <= 32'h0;
      end
      else begin
	 pc4_dly <= pc4;
      end
   end
   
      
	     
	     
   im #(.NMEM(NMEM), .IM_DATA(IM_DATA))
   im1(.addr                            (pc),
       .stall				(stall_iq),
       /*AUTOINST*/
       // Outputs
       .inst1				(inst1[31:0]),
       .inst1_valid			(inst1_valid),
       // Inputs
       .clk				(clk),
       .rst				(rst),
       .im_add				(im_add[31:0]),
       .im_data				(im_data[31:0]),
       .im_en				(im_en),
       .im_rd_wr			(im_rd_wr),
       .mispredict			(mispredict));

   
   iq u_iq (
	    .inst1_in			(inst1),
	    .inst1_in_valid		(inst1_valid),
	    .inst2_in			(0),
	    .inst2_in_valid		(0),
	    .iq_full			(stall_iq),
	    .singlemode			(1),
	    /*AUTOINST*/
	    // Outputs
	    .iq_empty			(iq_empty),
	    .inst1_out_valid		(inst1_out_valid),
	    .inst1_out			(inst1_out[31:0]),
	    .inst2_out_valid		(inst2_out_valid),
	    .inst2_out			(inst2_out[31:0]),
	    // Inputs
	    .clk			(clk),
	    .rst			(rst),
	    .stall_backend		(stall_backend),
	    .mispredict			(mispredict));
   

   
   assign opcode   = inst1[31:26];
   assign rs       = inst1[25:21];
   assign rt       = inst1[20:16];
   assign rd       = inst1[15:11];
   assign imm      = inst1[15:0];
   assign shamt    = inst1[10:6];
   assign jimm     = inst1[25:0];
   assign seimm    = {{16{inst1[15]}}, inst1[15:0]};
   assign funct    = inst1[5:0];
   

   reg [2:0]   inst_type;

   always @(*) begin
      // if not NOP
      if (|inst1) begin
	 case (opcode)
	   6'b000100, 6'b000101: begin //fixme:need to distinguish between BNE and BEQ
	      inst_type = `BRANCH;
	   end
	   6'b001000, 6'b000000: begin
	      inst_type = `ALU;
	   end
	   6'b100011: begin
	      inst_type = `LOAD;
	   end
	   6'b101011: begin
	      inst_type = `STORE;
	   end
	   default: begin
	      inst_type = `EMPTY;
	   end
	 endcase // case (opcode)
      end // if (|inst)
      else begin
	 inst_type = `EMPTY;
      end
   end // always @ (*)
   
   rb u_rb( 
	    .rst  (rst),
	    .clk (clk),
	    .wr_dest(0),
	    .wr_dest_en(1'b0),
	    .wr_dest_tag(0),
    	    .mem_value			(dm_rdata),
	    .stall			(stall_backend),
	    .inst_valid			(inst1_valid),
	    .pc4			(pc4_dly),
	    .pc4_undly                  (pc4),
	    /*AUTOINST*/
	   // Outputs
	   .pc_predict			(pc_predict[31:0]),
	   .predict_taken		(predict_taken),
	   .predict_valid		(predict_valid),
	   .mispredict			(mispredict),
	   .pc_resolved			(pc_resolved[31:0]),
	   .commit_dest			(commit_dest[6:0]),
	   .commit_value		(commit_value[31:0]),
	   .commit_mem_valid		(commit_mem_valid),
	   .commit_reg_valid		(commit_reg_valid),
	   .wr_regs_en			(wr_regs_en),
	   .wr_regs_tag			(wr_regs_tag[4:0]),
	   .wr_regs_rb_tag		(wr_regs_rb_tag[3:0]),
	   .lsu_s1			(lsu_s1[31:0]),
	   .lsu_A			(lsu_A[31:0]),
	   .alusrc1			(alusrc1[31:0]),
	   .alusrc2			(alusrc2[31:0]),
	   .alufunct			(alufunct[5:0]),
	   .aluopcode			(aluopcode[5:0]),
	   .mem_addr			(mem_addr[6:0]),
	   // Inputs
	   .inst_type			(inst_type[2:0]),
	   .rs				(rs[4:0]),
	   .rt				(rt[4:0]),
	   .rd				(rd[4:0]),
	   .imm				(imm[15:0]),
	   .seimm			(seimm[31:0]),
	   .seimm_sl2			(seimm_sl2[31:0]),
	   .funct			(funct[5:0]),
	   .opcode			(opcode[5:0]),
	   .rd_rb_tag1			(rd_rb_tag1[3:0]),
	   .rd_bsy1			(rd_bsy1),
	   .rd_rb_tag2			(rd_rb_tag2[3:0]),
	   .rd_bsy2			(rd_bsy2),
	   .reg_rs			(reg_rs[31:0]),
	   .reg_rt			(reg_rt[31:0]),
	   .lsu_addr			(lsu_addr[31:0]),
	   .alu_out			(alu_out[31:0]));
   

   regstatus u_regstatus( 
			  .rd_reg_tag1		(rs),
			  .rd_reg_tag2		(rt),
			  .commit_en		(commit_reg_valid),
			  .commit_reg_tag	(commit_dest[4:0]),
			  .flush_regs		(mispredict),
			  /*AUTOINST*/
			 // Outputs
			 .rd_rb_tag1		(rd_rb_tag1[3:0]),
			 .rd_bsy1		(rd_bsy1),
			 .rd_rb_tag2		(rd_rb_tag2[3:0]),
			 .rd_bsy2		(rd_bsy2),
			 // Inputs
			 .clk			(clk),
			 .rst			(rst),
			 .wr_regs_en		(wr_regs_en),
			 .wr_regs_tag		(wr_regs_tag[4:0]),
			 .wr_regs_rb_tag	(wr_regs_rb_tag[3:0]));
   
   
   

   // register memory
   regm regm1(.read1(rs), .read2(rt),
              .regwrite(commit_reg_valid), 
	      .wrreg(commit_dest),
              .wrdata(commit_value),
	      .data1(reg_rs),
	      .data2(reg_rt),
	      /*AUTOINST*/
	      // Inputs
	      .clk			(clk),
	      .rst			(rst));


   // shift left, seimm
   assign seimm_sl2 = {seimm[29:0], 2'b0};  // shift left 2 bits
   // branch address
   //wire [31:0] baddr_s2;
   //assign baddr_s2 = pc4_s2 + seimm_sl2;



   // ALU

   
   alu alu1(.funct(alufunct), 
	    .opcode(aluopcode), 
	    .a(alusrc1), 
	    .b(alusrc2), 
	    .out(alu_out),
	    .zero(zero_s3)
	    /*AUTOINST*/);

   
   
   //Address Generation Unit
   alu agu(.funct(5'd32), 
	   .opcode(5'h0), 
	   .a(lsu_s1), 
	   .b(lsu_A), 
	   .out(lsu_addr),
	   .zero()
	   /*AUTOINST*/); 
   
   // data memory
   dm dm1(.waddr(commit_dest),
	  .raddr(mem_addr),
	  .wr(commit_mem_valid),
	  .wdata(commit_value),
	  .rdata			(dm_rdata[31:0]),

	  /*AUTOINST*/
	  // Inputs
	  .clk				(clk),
	  .rst				(rst));


endmodule

// Emacs Verilog AUTOs
// Local Variables:
// verilog-library-directories:("." "../verilog")
// End:
