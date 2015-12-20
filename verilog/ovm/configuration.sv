`ifndef GUARD_CONFIGURATION
 `define GUARD_CONFIGURATION

// `include "ovm.svh"
//import ovm_pkg::*;
class configuration extends ovm_object;
   
   virtual mem_interface.MEM_cb mem_intf;
   virtual output_interface.OP output_intf;
   virtual internal_interface int_intf;
   
/* -----\/----- EXCLUDED -----\/-----
    function new(string name, virtual mem_interface.MEM_cb _if);
      super.new(name);
      this.mem_intf = _if;
   endfunction
 -----/\----- EXCLUDED -----/\----- */
   virtual function ovm_object create(string name = "");
      configuration t = new();

      t.mem_intf = this.mem_intf;
      t.output_intf = this.output_intf;
      t.int_intf = this.int_intf;
      return t;
      
   endfunction // create
   
endclass : configuration

`endif //  `ifndef GUARD_CONFIGURATION

      

