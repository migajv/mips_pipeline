class receiver extends ovm_component;

   virtual output_interface.OP output_intf;
   virtual internal_interface int_intf;
   
   configuration cfg;

   ovm_analysis_port #(packet) rcvr2sb_port;

   `ovm_component_utils(receiver)

   function new(string name = "", ovm_component parent);
      super.new(name, parent);
   endfunction: new  

   function void build ();
      super.build();
      rcvr2sb_port = new ("rcvr2sb",this);
   endfunction // build   

   function void end_of_elaboration();
      ovm_object tmp;
      super.end_of_elaboration();
      assert(get_config_object("configuration",tmp));
      assert($cast(cfg,tmp));
      this.output_intf = cfg.output_intf;
      this.int_intf = cfg.int_intf;
   endfunction // end_of_elaboration  

   task run();
      forever
	begin
	   @(posedge output_intf.clock)
	     begin
		if (output_intf.cb.pc == 32'h0050)
		  begin
		     //if ($root.top.DUT.regm1.mem[1] != 32'h5)
		     if (int_intf.reg5 != 32'h5)
		       ovm_report_error("receiver", "r1 is not 5 when finished");
		     global_stop_request();
		  end
	     end
	end
   endtask // run
   
      
endclass // receiver
