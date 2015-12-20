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
   
endinterface:mem_interface

interface input_interface(input bit clock);
   
   parameter setup_time = 5ns;
   parameter hold_time = 3ns;

   wire        dummy;

endinterface:input_interface

interface output_interface(input bit clock);
   
   parameter setup_time = 5ns;
   parameter hold_time = 3ns;
   
   wire [31:0] pc;
   wire [31:0] reg5;
   
   clocking cb@(posedge clock);
      default input #setup_time output #hold_time;
      input    pc;
      input    reg5;
      
   endclocking:cb   

   modport OP(clocking cb, input clock);
endinterface:output_interface

interface internal_interface(input wire [31:0] reg5);
endinterface // internal_interface

   

`endif //  `ifndef GUARD_INTERFACE

   
   
