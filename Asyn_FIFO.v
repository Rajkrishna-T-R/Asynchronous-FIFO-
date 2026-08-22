`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rajkrishna T R
// 
// Create Date: 01.08.2026 09:35:43
// Design Name: Asynchronous FIFO
// Module Name: Asyn_FIFO
// Project Name: Asynchronous FIFO
// Target Devices: FPGA (PYNQZ2)
// Tool Versions:  Vivado 2024.2
// Description: FIFO design with gray code encoding 
//              Depth of the FIFO is decided as 8 for initial design stage 
//              Clock frequencies is also not decided for now
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Asyn_FIFO#(parameter data_width=8,
                  parameter FIFO_depth=8)(
            
            input wire rclk,    //  read clock
            input wire rst_bar, // reset for clearing the entire array of data
            input wire [data_width-1:0]data_in, // input data
            input wire wclk,    // write clock
           
            
            input wire write_ready, // Write ready signal from source
            input wire read_ready,  // Read ready signal from destination
            
            output wire  fifo_full, // FIFO full  condition flag
            output wire  fifo_empty,// FIFO empty condition flag
            
            output wire  [data_width-1:0]data_out //output data
            
           
    );
    
    reg [data_width-1:0]DATA_out;
    assign data_out=DATA_out;
    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 
    localparam addr_size=$clog2(FIFO_depth); //  FIFO depth+1 should be needed?
                                               //  One extra bit needed for the overflow bit ????
    localparam ptr_size=addr_size+1;                                           
    //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
    reg [ptr_size-1:0]wr_ptr; // Write pointer
    reg [ptr_size-1:0]rd_ptr; // Read  pointer
    
    // FIFO buffer
    reg [data_width-1:0]FIFO_buf[0:FIFO_depth-1]; 
    
    reg FIFO_full_flg;
    reg FIFO_empty_flg;
    
    // Flag assignment for FULL and EMPTY conditions
    assign fifo_full=FIFO_full_flg;
    assign fifo_empty=FIFO_empty_flg;
    
    
    wire  write_en; // Write enable when FIFO not full and write_ready signal come from source
    wire  read_en;  // Read enable when the FIFO not full and read ready signal come from destination
    
      // Write enable condition 
       assign write_en=((~fifo_full)&(write_ready));
      // Read enable condition
       assign read_en=((~fifo_empty)&(read_ready));
      
    // Gray code versions of pointers
    wire [ptr_size-1:0]Rd_ptr_gray;
    wire [ptr_size-1:0]Wr_ptr_gray;
    
    // Two flop synchrnoiser write side to read side
    reg[ptr_size-1:0]Wr_ptr_syn1;
    reg[ptr_size-1:0]Wr_ptr_syn2;

    // Two flop synchroniser read side to write side
    reg[ptr_size-1:0]Rd_ptr_syn1;
    reg[ptr_size-1:0]Rd_ptr_syn2;
    
    // synchronised read and write pointer convted to binary value from gray code
    wire [ptr_size-1:0]Rd_ptr_syn_bin;
    wire [ptr_size-1:0]Wr_ptr_syn_bin;
    
    
    
  //---------------------------------------------------------------------------------------------  
    // Binary to Gray_code conversion function
    function [ptr_size-1:0]gray_out(binary_in);
             gray_out=binary_in^(binary_in>>1);
         endfunction
   
       // Gray code version of Read pointer in read side
       assign Rd_ptr_gray=gray_out(rd_ptr);
       // Gray code version of Write pointer in write side
       assign Wr_ptr_gray=gray_out(wr_ptr);
   //---------------------------------------------------------------------------------------------
   
   // Is this conversion necessary? Can i simplify this logic without ga=ray to binary?
   
              // NOTE: Validate the Timing on all the lines since all takes different time delays !!!
   
   // Gray to Binary conversion in Write side for read pointer
 
   genvar w;

    generate
        for (w = 0; w <= ptr_size-1; w = w + 1) begin : gen_block_read_ptr
            assign Rd_ptr_syn_bin[ptr_size-1-w]=^Rd_ptr_syn2[ptr_size-1:ptr_size-1-w];
        end
    endgenerate
   
              // NOTE: Validate the Timing on all the lines since all takes different time delays !!!
              
              
   // Gray to Binary conversion in Read side for Write pointer
 
   genvar r;

    generate
        for (r = 0; r <= ptr_size-1; r = r + 1) begin : gen_block_write_ptr
            assign Wr_ptr_syn_bin[ptr_size-1-r]=^Wr_ptr_syn2[ptr_size-1:ptr_size-1-r];
        end
    endgenerate
                
                
  //-------------------------------------------------------------------------------------------------
  
      
     // synchronising in read clock domain           
     always@(posedge rclk) 
        begin   
            if(!rst_bar)
                begin
                    Wr_ptr_syn1<={ptr_size{1'b0}};
                    Wr_ptr_syn2<={ptr_size{1'b0}};
                end
            else
                begin
                    Wr_ptr_syn1<=Wr_ptr_gray;
                    Wr_ptr_syn2<=Wr_ptr_syn1;
                 end
         end             
      // synchronising in write clock domain          
       always@(posedge wclk) 
        begin   
            if(!rst_bar)
                begin
                    Rd_ptr_syn1<={ptr_size{1'b0}};
                    Rd_ptr_syn2<={ptr_size{1'b0}};
                end
            else
                begin
                    Rd_ptr_syn1<=Rd_ptr_gray;
                    Rd_ptr_syn2<=Rd_ptr_syn1;
                 end
         end      
    
    
   // FIFO full flag calculation 
         always@(*)
            begin
                FIFO_full_flg=(({~wr_ptr[ptr_size-1],wr_ptr[ptr_size-2:0]})==Rd_ptr_syn_bin);
            end
            
   // FIFO empty flag calculation
            always@(*)
                begin
                    FIFO_empty_flg=(Wr_ptr_syn_bin==rd_ptr);
                end   
    
  
    
  
    
    // Write operation
    integer i;    // For resetting the memory        
    always@(posedge wclk)
        begin
            if(!rst_bar)
                begin // Synchronous Active Low reset
                // write side controll the reset signal.(Assumption for now)
                    for(i=0;i<FIFO_depth;i=i+1)
                        begin
                            FIFO_buf[i]<={(data_width){1'b0}};
                            wr_ptr<={ptr_size{1'b0}};
                        end
                end
                
             else 
                begin   
                    if(write_en==1)  //Write condition true
                        begin
                           FIFO_buf[wr_ptr[ptr_size-2:0]]<=data_in; // Write the new data
                           wr_ptr<=wr_ptr+1;          // Increment the  write pointer
                        end
                    else 
                        begin 
                            wr_ptr<=wr_ptr;           // Do not increment the write pointer
                        end
                end            
      
        end        
        
        
        
        
        // Read operation
      
    always@(posedge rclk)
        begin     
            if(!rst_bar)
                begin
                    rd_ptr<={ptr_size{1'b0}};       // Read pointer reset
                    DATA_out<={data_width-1{1'b0}};  // DATA out register reset
                end
            else 
                begin
                    if(read_en==1)  //Read condition true
                        begin
                           DATA_out<=FIFO_buf[rd_ptr[ptr_size-2:0]]; // read the new data (use the sync read pointer)
                           // error to be fixed
                           rd_ptr<=rd_ptr+1;          // Increment the  read pointer
                        end
                    else 
                        begin 
                            rd_ptr<=rd_ptr;           // Do not increment the read pointer
                        end
                end
        end        
                
endmodule
