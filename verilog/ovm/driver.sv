`ifndef GUARD_DRIVER
 `define GUARD_DRIVER
 //`include "ovm.svh"
//import ovm_pkg::*;

class driver extends ovm_driver #(packet);
   configuration cfg;
   static integer i ;
   packet pkt;
   virtual mem_interface.MEM_cb mem_intf;
   //virtual 	  mem_interface.MEM_1 mem_intf;
   
   ovm_analysis_port #(packet) drvr2sb_port;

   `ovm_component_utils_begin(driver)
      `ovm_field_object(cfg, OVM_ALL_ON)
   `ovm_component_utils_end

   function new(string name = "", ovm_component parent);
      super.new(name, parent);
      this.i = 0;
      
   endfunction: new

   function void build ();
      super.build();
      ovm_report_info(get_full_name(),"START of build", OVM_LOW);
      drvr2sb_port = new ("drvr2sb",this);
      ovm_report_info(get_full_name(),"END of build", OVM_LOW);
   endfunction // build

   function void end_of_elaboration();
      ovm_object tmp;
      super.end_of_elaboration();
      ovm_report_info(get_full_name(),"START of elaboration", OVM_LOW);
      assert(get_config_object("configuration",tmp));
      assert($cast(cfg,tmp));
      this.mem_intf = cfg.mem_intf;
      ovm_report_info(get_full_name(),"END of elaboration", OVM_LOW);
   endfunction // end_of_elaboration

   
   
   task run();
      forever begin
	 seq_item_port.get_next_item(pkt);
	 drvr2sb_port.write(pkt);
	 cfg_im(pkt);
	 seq_item_port.item_done();
      end 
   endtask // run

   virtual task cfg_im(packet pkt);
      ovm_report_info(get_full_name(),"START of cfg_im() method", OVM_LOW);
      @(posedge mem_intf.clock);
      mem_intf.cb.mem_rd_wr <= 1;
      mem_intf.cb.mem_add <= this.i;
      mem_intf.cb.mem_data <= pkt.ir;
      //mem_intf.mem_rd_wr = 1;
      //mem_intf.mem_add = this.i;
      //mem_intf.mem_data = pkt.ir;      
      this.i ++;
      $monitor ("i = %d", i);
      
      ovm_report_info(get_full_name(),"END of cfg_im() method", OVM_LOW);

   endtask // cfg_im

endclass // driver

`endif //  `ifndef GUARD_DRIVER

      
