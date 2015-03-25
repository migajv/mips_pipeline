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
      `ovm_do_with(item, {ir == 32'h20000001;});
   endtask // body

endclass // seq_2
