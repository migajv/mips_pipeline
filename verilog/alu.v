`ifndef _alu
`define _alu

module alu(
		input [5:0] 	  funct,
		input [5:0] 	  opcode,
		input [31:0] 	  a, b,
		output reg [31:0] out,
		output 		  zero);

   // control (opcode -> ...)
   wire        regdst;
   wire [1:0]  branch_s2;
   wire        memread;
   wire        memwrite;
   wire        memtoreg;
   wire [1:0]  aluop;
   wire        regwrite;
   wire        alusrc;
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
		.opcode			(opcode[5:0])); //fixme: opcode may need be stored in rob/rs   

   // ALU control
   wire [3:0]  aluctl;
   alu_control alu_ctl1(.aluop(aluop),
			/*AUTOINST*/
			// Outputs
			.aluctl		(aluctl[3:0]),
			// Inputs
			.funct		(funct[5:0]));//fixme: funct may need be stored in rob/rs
   
	wire [31:0] sub_ab;
	wire [31:0] add_ab;
	wire 		oflow_add;
	wire 		oflow_sub;
	wire 		oflow;
	wire 		slt;

	assign zero = (0 == out);

	assign sub_ab = a - b;
	assign add_ab = a + b;

	// overflow occurs (with 2's complement numbers) when
	// the operands have the same sign, but the sign of the result is
	// different.  The actual sign is the opposite of the result.
	// It is also dependent on wheter addition or subtraction is performed.
	assign oflow_add = (a[31] == b[31] && add_ab[31] != a[31]) ? 1 : 0;
	assign oflow_sub = (a[31] == b[31] && sub_ab[31] != a[31]) ? 1 : 0;

	assign oflow = (aluctl == 4'b0010) ? oflow_add : oflow_sub;

	// set if less than, 2s compliment 32-bit numbers
	assign slt = oflow_sub ? ~(a[31]) : a[31];

	always @(*) begin
		case (aluctl)
			4'b0010: out <= add_ab;				// a + b
			4'b0000: out <= a & b;				// and
			4'b1100: out <= ~(a | b);			// nor
			4'b0001: out <= a | b;				// or
			4'b0111: out <= {{31{1'b0}}, slt};	// set if less than
			4'b0110: out <= sub_ab;				// a - b
			4'b1101: out <= a ^ b;				// xor
			default: out <= 0;
		endcase
	end

endmodule

`endif
