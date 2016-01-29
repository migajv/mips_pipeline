class seq_1 extends ovm_sequence #(packet);
   function new (string name = "seq_1");
      super.new(name);
   endfunction // new

   packet item;

   `ovm_sequence_utils(seq_1, sequencer)

   virtual task body();
      `ovm_do_with(item, {ir == 32'h20020000;})
      `ovm_do_with(item, {ir == 32'h20030001;})
      `ovm_do_with(item, {ir == 32'h20080002;})
      `ovm_do_with(item, {ir == 32'h20090003;})
      `ovm_do_with(item, {ir == 32'h200A0004;})
      `ovm_do_with(item, {ir == 32'h200B0005;})
      `ovm_do_with(item, {ir == 32'h200C0006;})
   endtask // body

endclass // seq_1

class seq_2 extends ovm_sequence #(packet);
   function new (string name = "seq_2");
      super.new(name);
   endfunction // new

   packet item;

   `ovm_sequence_utils(seq_2, sequencer)

   virtual task body();
      //       addi R4, R0, 5
      // Loop: lw   R3, 24(R1)
      //       add  R5, R3, R1
      //       sw   R5, 24(R1)
      //       addi R1, R1, #1
      //       bne  R1, R4, LOOP
      
/* -----\/----- EXCLUDED -----\/-----
      `ovm_do_with(item, {ir == 32'h20040005;})
      `ovm_do_with(item, {ir == 32'h8c230018;})
      `ovm_do_with(item, {ir == 32'h00232820;})
      `ovm_do_with(item, {ir == 32'hac250018;})
      `ovm_do_with(item, {ir == 32'h20210001;})
      `ovm_do_with(item, {ir == 32'h1424fffb;})
 -----/\----- EXCLUDED -----/\----- */

      
      //       R4 <- 5   R2 <- 1 , R7 <- 1, R6 <- 2
      //       sw   R7, 20(R0)
      //       lw   R3, 20(R0)
      // Loop: add  R5, R3, R6
      //       add  R6, R6, R2
      //       bne  R6, R4, LOOP
      //       add  R5, R3, R6
/* -----\/----- EXCLUDED -----\/-----
      `ovm_do_with(item, {ir == 32'hac070014;})
      `ovm_do_with(item, {ir == 32'h8c030014;})
      `ovm_do_with(item, {ir == 32'h00662820;})
      `ovm_do_with(item, {ir == 32'h00c23020;})
      `ovm_do_with(item, {ir == 32'h14c4fffd;})
      `ovm_do_with(item, {ir == 32'h00662820;})
 -----/\----- EXCLUDED -----/\----- */


/* -----\/----- EXCLUDED -----\/-----
      main:0	lw  $3, 20($0) // R3 <- 10
	   4	lw  $4, 21($0) // R4 <- 3
	   8	add $5, $0, $0 // R5 <- 0
     loop1:c	add $5, $5, $2 // R5 ++
	   10	add $6, $0, $0 // R6 <- 0
     loop2:14	add $6, $6, $2 // R6 ++
	   18	add $7, $5, $6 // R7 <- R5 + R6
	   1c	bne $6, $4, loop2 // if R6 != 3 -> loop2 
	   20	bne $5, $3, loop1 // if R5 != 10 -> loop1
	   24	add $8, $0, $2
 -----/\----- EXCLUDED -----/\----- */
      `ovm_do_with(item, {ir == 32'h8c030014;})
      `ovm_do_with(item, {ir == 32'h8c040015;})
      `ovm_do_with(item, {ir == 32'h00002820;})
      `ovm_do_with(item, {ir == 32'h00a22820;})
      `ovm_do_with(item, {ir == 32'h00003020;})
      `ovm_do_with(item, {ir == 32'h00c23020;})
      `ovm_do_with(item, {ir == 32'h00a63820;})
      `ovm_do_with(item, {ir == 32'h14c4fffd;})
      `ovm_do_with(item, {ir == 32'h14a3fffa;})
      `ovm_do_with(item, {ir == 32'h00024020;})
      
   endtask // body

endclass // seq_2

class seq_add extends ovm_sequence #(packet);
   
   function new(string name = "seq_add");
      super.new(name);
   endfunction // new

   packet item;
   `ovm_sequence_utils(seq_add, sequencer)
   virtual task body();
      
   `ovm_do_with(item, {ir[31:26] == 6'b000000; 
		       ir[5:0] == 6'b000000; 
		       ir[25:21] > 0;   ir[25:21] <= 3;
		       ir[20:16] > 0;   ir[20:16] <= 3;
		       ir[15:11] > 0;   ir[15:11] <= 3;
		       });
   `ovm_do_with(item, {ir[31:26] == 6'b000000; 
		       ir[5:0] == 6'b000000; 
		       ir[25:21] > 0;   ir[25:21] <= 3;
		       ir[20:16] > 0;   ir[20:16] <= 3;
		       ir[15:11] > 0;   ir[15:11] <= 3;
		       });
    `ovm_do_with(item, {ir[31:26] == 6'b000000; 
		       ir[5:0] == 6'b000000; 
		       ir[25:21] > 0;   ir[25:21] <= 3;
		       ir[20:16] > 0;   ir[20:16] <= 3;
		       ir[15:11] > 0;   ir[15:11] <= 3;
		       });
  
   endtask // body

endclass // seq_add
