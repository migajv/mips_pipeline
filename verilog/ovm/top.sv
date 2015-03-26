`ifndef GUARD_TOP
 `define GUARD_TOP

 `include "ovm.svh"
//import ovm_pkg::*;

module top();

 `include "packet.sv"  
 `include "configuration.sv"
 `include "sequencer.sv"
 `include "sequence.sv"
 `include "driver.sv"
 `include "environment.sv"
 `include "test.sv"
   
   //clock delcaration and generation
   bit clock_mem;
   bit clock_dut;
   initial
     begin
        #20;
	fork
	   begin
              forever #10 clock_mem = ~clock_mem;
	   end
	   begin
	      #100;
	      forever #10 clock_dut = ~clock_dut;
	   end
	join_none
     end // initial begin

   //memory interface instance
   mem_interface mem_intf(clock_mem);

   configuration cfg = new("cfg",mem_intf);

   cpu DUT (.clk(clock_dut),
            .im_add(mem_intf.mem_add),
	    .im_data(mem_intf.mem_data),
	    .im_en(mem_intf.mem_en),
	    .im_rd_wr(mem_intf.mem_rd_wr));

   
   initial
     begin
	set_config_object("*.drvr","configuration",cfg,0);
	run_test();
     end
   


endmodule:top
`endif //  `ifndef GUARD_TOP

        
   
