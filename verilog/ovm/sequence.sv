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
      
      `ovm_do_with(item, {ir == 32'h20040005;})
      `ovm_do_with(item, {ir == 32'h8c230018;})
      `ovm_do_with(item, {ir == 32'h00232820;})
      `ovm_do_with(item, {ir == 32'hac250018;})
      `ovm_do_with(item, {ir == 32'h20210001;})
      `ovm_do_with(item, {ir == 32'h1424fffb;})
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
