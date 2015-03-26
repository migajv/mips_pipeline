`ifndef GUARD_CONFIGURATION
 `define GUARD_CONFIGURATION

// `include "ovm.svh"
//import ovm_pkg::*;
class configuration extends ovm_object;
   
   virtual mem_interface.MEM_cb mem_intf;
   //virtual mem_interface.MEM_1 mem_intf;
   
    function new(string name, virtual mem_interface.MEM_cb _if);
//    function new(string name, virtual mem_interface.MEM_1 _if);
      super.new(name);
      this.mem_intf = _if;
   endfunction // new
   
endclass : configuration

`endif //  `ifndef GUARD_CONFIGURATION

      

