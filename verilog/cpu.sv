/*
 * cpu. - five stage MIPS CPU.
 *
 * Many variables (wires) pass through several stages.
 * The naming convention used for each stage is
 * accomplished by appending the stage number (_s<num>).
 * For example the variable named "data" which is
 * in stage 2 and stage 3 would be named as follows.
 *
 * wire data_s2;
 * wire data_s3;
 *      
 * If the stage number is omitted it is assumed to
 * be at the stage at which the variable is first
 * established.
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

`ifndef DEBUG_CPU_STAGES
 `define DEBUG_CPU_STAGES 0
`endif

module cpu(
           input wire 	     clk,
	   input wire        rst,
           input wire [31:0] im_add,
           input wire [31:0] im_data,
           input wire 	     im_en,
           input wire 	     im_rd_wr,
	   output reg [31:0] pc
	   /*AUTOARG*/);


      // decode instruction
   wire [5:0]  opcode;
   wire [4:0]  rs;
   wire [4:0]  rt;
   wire [4:0]  rd;
   wire [15:0] imm;
   wire [4:0]  shamt;
   wire [25:0] jimm;  // jump, immediate
   wire [31:0] seimm;  // sign extended immediate
   //
/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
logic [5:0]		alufunct;		// From u_rb of rb.v
logic [5:0]		aluopcode;		// From u_rb of rb.v
logic [31:0]		alusrc1;		// From u_rb of rb.v
logic [31:0]		alusrc2;		// From u_rb of rb.v
logic [6:0]		commit_dest;		// From u_rb of rb.v
logic			commit_mem_valid;	// From u_rb of rb.v
logic			commit_reg_valid;	// From u_rb of rb.v
logic [31:0]		commit_value;		// From u_rb of rb.v
logic [31:0]		lsu_A;			// From u_rb of rb.v
logic [31:0]		lsu_s1;			// From u_rb of rb.v
wire			lsu_wr;			// From u_rb of rb.v
logic [6:0]		mem_addr;		// From u_rb of rb.v
logic			mispredict;		// From u_rb of rb.v
logic [31:0]		pc_predict;		// From u_rb of rb.v
logic [31:0]		pc_resolved;		// From u_rb of rb.v
logic			predict_taken;		// From u_rb of rb.v
logic			predict_valid;		// From u_rb of rb.v
wire			rd_bsy1;		// From u_regstatus of regstatus.v
wire			rd_bsy2;		// From u_regstatus of regstatus.v
wire [3:0]		rd_rb_tag1;		// From u_regstatus of regstatus.v
wire [3:0]		rd_rb_tag2;		// From u_regstatus of regstatus.v
wire			stall;			// From u_rb of rb.v
logic			wr_regs_en;		// From u_rb of rb.v
logic [3:0]		wr_regs_rb_tag;		// From u_rb of rb.v
logic [4:0]		wr_regs_tag;		// From u_rb of rb.v
// End of automatics
   
   parameter NMEM = 20;  // number in instruction memory
   parameter IM_DATA = "im_data.txt";

   // {{{ diagnostic outputs
   initial begin
      if (`DEBUG_CPU_STAGES) begin
         $display("if_pc,    if_instr, id_regrs, id_regrt, ex_alua,  ex_alub,  ex_aluctl, mem_memdata, mem_memread, mem_memwrite, wb_regdata, wb_regwrite");
         $monitor("%x, %x, %x, %x, %x, %x, %x,         %x,    %x,           %x,            %x,   %x",
                  pc,                           /* if_pc */
                  inst,                 /* if_instr */
                  data1,                        /* id_regrs */
                  data2,                        /* id_regrt */
                  data1_s3,             /* data1_s3 */
                  alusrc_data2, /* alusrc_data2 */
                  aluctl,                       /* ex_aluctl */
                  data2_s4,             /* mem_memdata */
                  memread_s4,           /* mem_memread */
                  memwrite_s4,  /* mem_memwrite */
                  wrdata_s5,            /* wb_regdata */
                  regwrite_s5           /* wb_regwrite */
                  );
      end
   end
   // }}}

   rb u_rb( 
	    .rst (rst),
	    .clk (clk),
	    .inst_type(2'b00),
	    .rt(rt),
	    .rd(rd),
	    .wr_value(32'h0),
	    .wr_value_en(1'b0),
	    .wr_value_tag(0),
	    .wr_dest(0),
	    .wr_dest_en(1'b0),
	    .wr_dest_tag(0),
	    .inst_valid(0),
	    .reg_rs			(0),
	   .reg_rt			(0),
	    /*AUTOINST*/
	   // Outputs
	   .stall			(stall),
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
	   .lsu_wr			(lsu_wr),
	   .alusrc1			(alusrc1[31:0]),
	   .alusrc2			(alusrc2[31:0]),
	   .alufunct			(alufunct[5:0]),
	   .aluopcode			(aluopcode[5:0]),
	   .mem_addr			(mem_addr[6:0]),
	   // Inputs
	   .rs				(rs[4:0]),
	   .imm				(imm[15:0]),
	   .seimm_sl2			(seimm_sl2[31:0]),
	   .pc4				(pc4[31:0]),
	   .funct			(funct[5:0]),
	   .opcode			(opcode[5:0]),
	   .rd_rb_tag1			(rd_rb_tag1[3:0]),
	   .rd_bsy1			(rd_bsy1),
	   .rd_rb_tag2			(rd_rb_tag2[3:0]),
	   .rd_bsy2			(rd_bsy2),
	   .lsu_addr_done		(lsu_addr_done),
	   .lsu_addr			(lsu_addr[31:0]),
	   .mem_value			(mem_value[31:0]),
	   .mem_valid			(mem_valid),
	   .alu_out			(alu_out[31:0]));
   

   regstatus u_regstatus( 
			  .rd_reg_tag1		(0),
			  .rd_reg_tag2		(0),
			  .commit_en		(0),
			  .commit_reg_tag	(0),
			 .wr_regs_tag		(wr_regs_tag),
			 .wr_regs_rb_tag	(wr_regs_rb_tag),			  
			  /*AUTOINST*/
			 // Outputs
			 .rd_rb_tag1		(rd_rb_tag1[3:0]),
			 .rd_bsy1		(rd_bsy1),
			 .rd_rb_tag2		(rd_rb_tag2[3:0]),
			 .rd_bsy2		(rd_bsy2),
			 // Inputs
			 .clk			(clk),
			 .rst			(rst),
			 .wr_regs_en		(wr_regs_en));
   
   
   // {{{ flush control
   reg flush_s1, flush_s2, flush_s3;
   reg pcsrc;
   always @(*) begin
      flush_s1 <= 1'b0;
      flush_s2 <= 1'b0;
      flush_s3 <= 1'b0;
      if (pcsrc) begin
         flush_s1 <= 1'b1;
         flush_s2 <= 1'b1;
         flush_s3 <= 1'b1;
      end
   end
   // }}}

   // {{{ stage 1, IF (fetch)

   initial begin
      pc <= 32'd0;
   end

   wire [31:0] pc4;  // PC + 4
   assign pc4 = pc + 4;

   reg         stall_s1_s2;
   wire [31:0] baddr_s4;
   
   always @(posedge clk) begin
      if (stall_s1_s2) 
        pc <= pc;
      else if (pcsrc == 1'b1)
        pc <= baddr_s4;
      else
        pc <= pc4;
   end

   // pass PC + 4 to stage 2
   wire [31:0] pc4_s2;
   regr #(.N(32)) regr_pc4_s2(.hold(stall_s1_s2), .clear(flush_s1),
                              .in(pc4), .out(pc4_s2),
			      /*AUTOINST*/
			      // Inputs
			      .clk		(clk),
			      .rst		(rst));

   // instruction memory
   wire [31:0] inst;
   wire [31:0] inst_s2;
   im #(.NMEM(NMEM), .IM_DATA(IM_DATA))
   im1(.addr(pc),
       .data(inst),
       /*AUTOINST*/
       // Inputs
       .clk				(clk),
       .rst				(rst),
       .im_add				(im_add[31:0]),
       .im_data				(im_data[31:0]),
       .im_en				(im_en),
       .im_rd_wr			(im_rd_wr));
   regr #(.N(32)) regr_im_s2(.hold(stall_s1_s2), .clear(flush_s1),
                             .in(inst), .out(inst_s2),
			     /*AUTOINST*/
			     // Inputs
			     .clk		(clk),
			     .rst		(rst));

   // }}}

   // {{{ stage 2, ID (decode)


   assign opcode   = inst_s2[31:26];
   assign rs       = inst_s2[25:21];
   assign rt       = inst_s2[20:16];
   assign rd       = inst_s2[15:11];
   assign imm      = inst_s2[15:0];
   assign shamt    = inst_s2[10:6];
   assign jimm     = inst_s2[25:0];
   assign seimm         = {{16{inst_s2[15]}}, inst_s2[15:0]};

   // register memory
   wire [31:0] data1, data2;
   wire        regwrite_s5;
   wire [4:0]  wrreg_s5;
   wire [31:0] wrdata_s5;
   regm regm1(.read1(rs), .read2(rt),
              .regwrite(regwrite_s5), .wrreg(wrreg_s5),
              .wrdata(wrdata_s5),
	      /*AUTOINST*/
	      // Outputs
	      .data1			(data1[31:0]),
	      .data2			(data2[31:0]),
	      // Inputs
	      .clk			(clk),
	      .rst			(rst));

   // pass rs to stage 3 (for forwarding)
   wire [4:0]  rs_s3;
   regr #(.N(5)) regr_s2_rs(.clear(1'b0), .hold(stall_s1_s2),
                            .in(rs), .out(rs_s3),
			    /*AUTOINST*/
			    // Inputs
			    .clk		(clk),
			    .rst		(rst));

   // transfer register data to stage 3
   wire [31:0] data1_s3, data2_s3;
   regr #(.N(64)) reg_s2_mem(.clear(flush_s2), .hold(stall_s1_s2),
                             .in({data1, data2}),
                             .out({data1_s3, data2_s3}),
			     /*AUTOINST*/
			     // Inputs
			     .clk		(clk),
			     .rst		(rst));

   // transfer seimm, rt, and rd to stage 3
   wire [31:0] seimm_s3;
   wire [4:0]  rt_s3;
   wire [4:0]  rd_s3;
   regr #(.N(32)) reg_s2_seimm(.clear(flush_s2), .hold(stall_s1_s2),
                               .in(seimm), .out(seimm_s3),
			       /*AUTOINST*/
			       // Inputs
			       .clk		(clk),
			       .rst		(rst));
   regr #(.N(10)) reg_s2_rt_rd(.clear(flush_s2), .hold(stall_s1_s2),
                               .in({rt, rd}), .out({rt_s3, rd_s3}),
			       /*AUTOINST*/
			       // Inputs
			       .clk		(clk),
			       .rst		(rst));

   // transfer PC + 4 to stage 3
   wire [31:0] pc4_s3;
   regr #(.N(32)) reg_pc4_s2(.clear(1'b0), .hold(stall_s1_s2),
                             .in(pc4_s2), .out(pc4_s3),
			     /*AUTOINST*/
			     // Inputs
			     .clk		(clk),
			     .rst		(rst));

   // control (opcode -> ...)
   wire        regdst;
   wire [1:0]  branch_s2;
   wire        memread;
   wire        memwrite;
   wire        memtoreg;
   wire [1:0]  aluop;
   wire        regwrite;
   wire        alusrc;
   //
   control ctl1(.branch(branch_s2),
		/*AUTOINST*/
		// Outputs
		.regdst			(regdst),
		.memread		(memread),
		.memtoreg		(memtoreg),
		.aluop			(aluop[1:0]),
		.memwrite		(memwrite),
		.alusrc			(alusrc),
		.regwrite		(regwrite),
		// Inputs
		.opcode			(opcode[5:0]));

   // shift left, seimm
   wire [31:0] seimm_sl2;
   assign seimm_sl2 = {seimm[29:0], 2'b0};  // shift left 2 bits
   // branch address
   wire [31:0] baddr_s2;
   assign baddr_s2 = pc4_s2 + seimm_sl2;

   // transfer the control signals to stage 3
   wire        regdst_s3;
   wire        memread_s3;
   wire        memwrite_s3;
   wire        memtoreg_s3;
   wire [1:0]  aluop_s3;
   wire        regwrite_s3;
   wire        alusrc_s3;
   // A bubble is inserted by setting all the control signals
   // to zero (stall_s1_s2).
   regr #(.N(8)) reg_s2_control(.clear(stall_s1_s2), .hold(1'b0),
				.in({regdst, memread, memwrite,
				     memtoreg, aluop, regwrite, alusrc}),
				.out({regdst_s3, memread_s3, memwrite_s3,
				      memtoreg_s3, aluop_s3, regwrite_s3, alusrc_s3}),
				/*AUTOINST*/
				// Inputs
				.clk		(clk),
				.rst		(rst));

   wire [1:0]  branch_s3;
   regr #(.N(2)) branch_s2_s3(.clear(flush_s2), .hold(1'b0),
			      .in(branch_s2), .out(branch_s3),
			      /*AUTOINST*/
			      // Inputs
			      .clk		(clk),
			      .rst		(rst));

   wire [31:0] baddr_s3;
   regr #(.N(32)) baddr_s2_s3(.clear(flush_s2), .hold(1'b0),
			      .in(baddr_s2), .out(baddr_s3),
			      /*AUTOINST*/
			      // Inputs
			      .clk		(clk),
			      .rst		(rst));
   // }}}

   // {{{ stage 3, EX (execute)

   // pass through some control signals to stage 4
   wire        regwrite_s4;
   wire        memtoreg_s4;
   wire        memread_s4;
   wire        memwrite_s4;
   regr #(.N(4)) reg_s3(.clear(flush_s2), .hold(1'b0),
			.in({regwrite_s3, memtoreg_s3, memread_s3,
			     memwrite_s3}),
			.out({regwrite_s4, memtoreg_s4, memread_s4,
			      memwrite_s4}),
			/*AUTOINST*/
			// Inputs
			.clk		(clk),
			.rst		(rst));

   // ALU
   // second ALU input can come from an immediate value or data
   wire [31:0] alusrc_data2;
   reg [31:0]  fw_data2_s3;
   assign alusrc_data2 = (alusrc_s3) ? seimm_s3 : fw_data2_s3;
   // ALU control
   wire [3:0]  aluctl;
   wire [5:0]  funct;
   assign funct = seimm_s3[5:0];
   alu_control alu_ctl1(.aluop(aluop_s3),
			/*AUTOINST*/
			// Outputs
			.aluctl		(aluctl[3:0]),
			// Inputs
			.funct		(funct[5:0]));
   // ALU
   wire [31:0] alurslt;
   reg [31:0]  fw_data1_s3;
   wire [31:0] alurslt_s4;
   reg [1:0]   forward_a;
   reg [1:0]   forward_b;
   always @(*)
     case (forward_a)
       2'd1: fw_data1_s3 = alurslt_s4;
       2'd2: fw_data1_s3 = wrdata_s5;
       default: fw_data1_s3 = data1_s3;
     endcase
   wire        zero_s3;
   alu alu1(.ctl(aluctl), .a(fw_data1_s3), .b(alusrc_data2), .out(alurslt),
	    .zero(zero_s3),
	    /*AUTOINST*/
	    // Inputs
	    .funct			(funct[5:0]),
	    .opcode			(opcode[5:0]));
   wire        zero_s4;
   regr #(.N(1)) reg_zero_s3_s4(.clear(1'b0), .hold(1'b0),
				.in(zero_s3), .out(zero_s4),
				/*AUTOINST*/
				// Inputs
				.clk		(clk),
				.rst		(rst));

   // pass ALU result and zero to stage 4
   
   regr #(.N(32)) reg_alurslt(.clear(flush_s3), .hold(1'b0),
			      .in({alurslt}),
			      .out({alurslt_s4}),
			      /*AUTOINST*/
			      // Inputs
			      .clk		(clk),
			      .rst		(rst));

   // pass data2 to stage 4
   wire [31:0] data2_s4;
   
   always @(*)
     case (forward_b)
       2'd1: fw_data2_s3 = alurslt_s4;
       2'd2: fw_data2_s3 = wrdata_s5;
       default: fw_data2_s3 = data2_s3;
     endcase
   regr #(.N(32)) reg_data2_s3(.clear(flush_s3), .hold(1'b0),
			       .in(fw_data2_s3), .out(data2_s4),
			       /*AUTOINST*/
			       // Inputs
			       .clk		(clk),
			       .rst		(rst));

   // write register
   wire [4:0]  wrreg;
   wire [4:0]  wrreg_s4;
   assign wrreg = (regdst_s3) ? rd_s3 : rt_s3;
   // pass to stage 4
   regr #(.N(5)) reg_wrreg(.clear(flush_s3), .hold(1'b0),
			   .in(wrreg), .out(wrreg_s4),
			   /*AUTOINST*/
			   // Inputs
			   .clk			(clk),
			   .rst			(rst));

   wire [1:0]  branch_s4;
   regr #(.N(2)) branch_s3_s4(.clear(flush_s3), .hold(1'b0),
			      .in(branch_s3), .out(branch_s4),
			      /*AUTOINST*/
			      // Inputs
			      .clk		(clk),
			      .rst		(rst));

   
   regr #(.N(32)) baddr_s3_s4(.clear(flush_s3), .hold(1'b0),
			      .in(baddr_s3), .out(baddr_s4),
			      /*AUTOINST*/
			      // Inputs
			      .clk		(clk),
			      .rst		(rst));
   // }}}

   // {{{ stage 4, MEM (memory)

   // pass regwrite and memtoreg to stage 5
   
   wire        memtoreg_s5;
   regr #(.N(2)) reg_regwrite_s4(.clear(1'b0), .hold(1'b0),
				 .in({regwrite_s4, memtoreg_s4}),
				 .out({regwrite_s5, memtoreg_s5}),
				 /*AUTOINST*/
				 // Inputs
				 .clk			(clk),
				 .rst			(rst));

   // data memory
   wire [31:0] rdata;
   dm dm1(.addr(alurslt_s4[8:2]), .rd(memread_s4), .wr(memwrite_s4),
	  .wdata(data2_s4),
	  /*AUTOINST*/
	  // Outputs
	  .rdata			(rdata[31:0]),
	  // Inputs
	  .clk				(clk),
	  .rst				(rst));
   // pass read data to stage 5
   wire [31:0] rdata_s5;
   regr #(.N(32)) reg_rdata_s4(.clear(1'b0), .hold(1'b0),
			       .in(rdata),
			       .out(rdata_s5),
			       /*AUTOINST*/
			       // Inputs
			       .clk		(clk),
			       .rst		(rst));

   // pass alurslt to stage 5
   wire [31:0] alurslt_s5;
   regr #(.N(32)) reg_alurslt_s4(.clear(1'b0), .hold(1'b0),
				 .in(alurslt_s4),
				 .out(alurslt_s5),
				 /*AUTOINST*/
				 // Inputs
				 .clk			(clk),
				 .rst			(rst));

   // pass wrreg to stage 5
   
   regr #(.N(5)) reg_wrreg_s4(.clear(1'b0), .hold(1'b0),
			      .in(wrreg_s4),
			      .out(wrreg_s5),
			      /*AUTOINST*/
			      // Inputs
			      .clk		(clk),
			      .rst		(rst));

   // branch
   always @(*) begin
      case (1'b1)
	branch_s4[`BRANCH_BEQ]: pcsrc <= zero_s4;
	branch_s4[`BRANCH_BNE]: pcsrc <= ~(zero_s4);
	default: pcsrc <= 1'b0;
      endcase
   end
   // }}}
   
   // {{{ stage 5, WB (write back)

   
   assign wrdata_s5 = (memtoreg_s5 == 1'b1) ? rdata_s5 : alurslt_s5;

   // }}}

   // {{{ forwarding

   // stage 3 (MEM) -> stage 2 (EX)
   // stage 4 (WB) -> stage 2 (EX)

   // FIXME:JR: need to add condition that rs_s3 != 0 and forward from stage 5 only if stage 4 would not forward. e.g. add $1,$1,$2; add $1,$1,$3; add $1,$1,$4
   
   always @(*) begin
      // If the previous instruction (stage 4) would write,
      // and it is a value we want to read (stage 3), forward it.

      // data1 input to ALU
      if ((regwrite_s4 == 1'b1) && (wrreg_s4 == rs_s3)) begin
	 forward_a <= 2'd1;  // stage 4
      end else if ((regwrite_s5 == 1'b1) && (wrreg_s5 == rs_s3)) begin
	 forward_a <= 2'd2;  // stage 5
      end else
	forward_a <= 2'd0;  // no forwarding

      // data2 input to ALU
      if ((regwrite_s4 == 1'b1) & (wrreg_s4 == rt_s3)) begin
	 forward_b <= 2'd1;  // stage 5
      end else if ((regwrite_s5 == 1'b1) && (wrreg_s5 == rt_s3)) begin
	 forward_b <= 2'd2;  // stage 5
      end else
	forward_b <= 2'd0;  // no forwarding
   end
   // }}}

   // {{{ load use data hazard detection, signal stall

   /* If an operation in stage 4 (MEM) loads from memory (e.g. lw)
    * and the operation in stage 3 (EX) depends on this value,
    * a stall must be performed.  The memory read cannot 
    * be forwarded because memory access is too slow.  It can
    * be forwarded from stage 5 (WB) after a stall.
    *
    *   lw $1, 16($10)  ; I-type, rt_s3 = $1, memread_s3 = 1
    *   sw $1, 32($12)  ; I-type, rt_s2 = $1, memread_s2 = 0
    *
    *   lw $1, 16($3)  ; I-type, rt_s3 = $1, memread_s3 = 1
    *   sw $2, 32($1)  ; I-type, rt_s2 = $2, rs_s2 = $1, memread_s2 = 0
    *
    *   lw  $1, 16($3)  ; I-type, rt_s3 = $1, memread_s3 = 1
    *   add $2, $1, $1  ; R-type, rs_s2 = $1, rt_s2 = $1, memread_s2 = 0
    */
   
   always @(*) begin
      if (memread_s3 == 1'b1 && ((rt == rt_s3) || (rs == rt_s3)) ) begin
	 stall_s1_s2 <= 1'b1;  // perform a stall
      end else
	stall_s1_s2 <= 1'b0;  // no stall
   end
   // }}}

endmodule

// Emacs Verilog AUTOs
// Local Variables:
// verilog-library-directories:("." "../verilog")
// End:
