// `include "ovm.svh"
//import ovm_pkg::*;

class test1 extends ovm_test;
   `ovm_component_utils(test1)

   environment t_env;
   //configuration cfg;
   
   function new(string name="test1",ovm_component parent=null);
      super.new(name, parent);
      
   endfunction: new

   function void build();
      super.build();
      set_config_int("*","recording_detail",OVM_FULL);
      
      set_config_string("*.seqncr", "default_sequence", "seq_1");
      set_config_string("*.seqncr", "count", 2);

      t_env = environment::type_id::create("t_env",this);
   endfunction // build
   
   
   task run();
      t_env.seqncr.print();
      #1000;
      global_stop_request();
   endtask:run

endclass : test1

      
