`ifndef GUARD_PACKET
 `define GUARD_PACKET

 //`include "ovm.svh"
//import ovm_pkg::*;

class packet extends ovm_sequence_item;

   rand bit [31:0] ir;

   function new (string name = "");
      super.new(name);
   endfunction : new
   
    `ovm_object_utils_begin(packet)
      `ovm_field_int(ir, OVM_ALL_ON + OVM_HEX) // Avoids the need to override do_print
    `ovm_object_utils_end
   
   //constraint c_IR { IR == 32'h20000000; }
   
endclass : packet

`endif //  `ifndef GUARD_PACKET
