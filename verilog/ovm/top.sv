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
 `include "receiver.sv"
 `include "environment.sv"
 `include "test.sv"
   
   //clock delcaration and generation
   bit clock_mem;
   bit clock_dut;
   bit rst_dut;
   initial
     begin
	#10;
	rst_dut = 0;
	#10;
	rst_dut = 1;
        #10;
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
   // output_interface output_intf(clock_dut);
   //internal_interface int_intf();
   
   
   configuration cfg;

   cpu DUT (.clk(clock_dut),
	    .rst(rst_dut),
            .im_add(mem_intf.mem_add),
	    .im_data(mem_intf.mem_data),
	    .im_en(mem_intf.mem_en),
	    .im_rd_wr(mem_intf.mem_rd_wr),
	    .pc (output_intf.pc)
	    );

   bind DUT internal_interface int_intf(.reg5(regm1.mem[1]));
   
   initial
     begin
	$shm_open("waves.shm");
	$shm_probe("AS");

	cfg = new();
	cfg.mem_intf = mem_intf;
	cfg.output_intf = output_intf;
	cfg.int_intf = DUT.int_intf;
	
	set_config_object("*.*","configuration",cfg,0);
	run_test();
     end
   


endmodule:top
`endif //  `ifndef GUARD_TOP

        
   
