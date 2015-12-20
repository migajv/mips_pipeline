`ifndef GUARD_ENV
 `define GUARD_ENV

 //`include "ovm.svh"
//import ovm_pkg::*;

class environment extends ovm_env;
   `ovm_component_utils(environment)

   sequencer seqncr;
   driver drvr;
   receiver rcvr;
   
   function new(string name = "environment", ovm_component parent = null);
      super.new(name, parent);
      ovm_report_info("", "Called my_env::new");
   endfunction: new

   function void build();
      super.build();
      ovm_report_info(get_full_name(),"START of build", OVM_LOW);
      drvr = driver::type_id::create("drvr",this);
      seqncr = sequencer::type_id::create("seqncr",this);
      rcvr = receiver::type_id::create("rcvr",this);
      ovm_report_info(get_full_name(),"END of build", OVM_LOW);
   endfunction // build

   function void connect();
      super.connect();
      ovm_report_info("", "Called my_env::connect");
      ovm_report_info(get_full_name(),"START of connect", OVM_LOW);

      drvr.seq_item_port.connect(seqncr.seq_item_export);
      
      ovm_report_info(get_full_name(),"END of connect", OVM_LOW);
   endfunction // connect

endclass: environment
`endif //  `ifndef GUARD_ENV
