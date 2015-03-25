`ifndef GUARD_INTERFACE
 `define GUARD_INTERFACE

interface mem_interface(input bit clock);

   parameter setup_time = 5ns;
   parameter hold_time = 3ns;

   bit [31:0] mem_data;
   bit [31:0] mem_add;
   bit        mem_en;
   bit        mem_rd_wr;

   clocking cb@(posedge clock);
      default input #setup_time output #hold_time;
      output   mem_data;
      output   mem_add;      
      output   mem_en;
      output   mem_rd_wr;
   endclocking:cb

   modport MEM_cb(clocking cb, input clock);
   modport MEM_1(      output   mem_data, mem_add, mem_en, mem_rd_wr);
   
endinterface:mem_interface

interface input_interface(input bit clock);
   
   parameter setup_time = 5ns;
   parameter hold_time = 3ns;

   wire        dummy;

endinterface:input_interface

      
`endif //  `ifndef GUARD_INTERFACE

   
   
