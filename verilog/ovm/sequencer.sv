`ifndef GUARD_SEQUENCER
 `define GUARD_SEQUENCER

// `include "ovm.svh"
//import ovm_pkg::*;

class sequencer extends ovm_sequencer # (packet);
   configuration cfg;

   `ovm_sequencer_utils(sequencer)

   function new (string name, ovm_component parent);
      super.new(name,parent);
      `ovm_update_sequence_lib_and_item(packet)
   endfunction // new

endclass // sequencer

`endif //  `ifndef GUARD_SEQUENCER

	
