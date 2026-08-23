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

//              Is the reset signal needed to be synchronised across the domains??
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
   
    localparam addr_size=$clog2(FIFO_depth);  // The Address size that is actually used for the data storage
    localparam ptr_size=addr_size+1;          // The Address size used for pointers, 
    // also this will be used for the wrap around of the address and
    // to generate the full  and empty conditions                                
    
    
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
    reg[ptr_size-1:0]Wr_ptr_syn1_gray;
    reg[ptr_size-1:0]Wr_ptr_syn2_gray;  //  Used for comparison

    // Two flop synchroniser read side to write side
    reg[ptr_size-1:0]Rd_ptr_syn1_gray;
    reg[ptr_size-1:0]Rd_ptr_syn2_gray;  // Used for comparison 
    
    // Reset synchronising
    
    reg rst_bar_sync1;
    reg rst_bar_sync2;
    
  //---------------------------------------------------------------------------------------------
   // the reset signal synchrnoised to read domain to reset the read side
    always@(posedge rclk)
        begin
            rst_bar_sync1<=rst_bar;
            rst_bar_sync2<=rst_bar_sync1;
        end
  //---------------------------------------------------------------------------------------------  
    // Binary to Gray_code conversion function
    // Automatic used since each function call needs to separate memory allocation so that no overwrite occurs
    function automatic [ptr_size-1:0]gray_out(binary_in);
             gray_out=binary_in^(binary_in>>1);
         endfunction
   
       // Gray code version of Read pointer in read side
       assign Rd_ptr_gray=gray_out(rd_ptr);
       // Gray code version of Write pointer in write side
       assign Wr_ptr_gray=gray_out(wr_ptr);
   //---------------------------------------------------------------------------------------------
        /// Two flop synchronisers
      
     // synchronising in read clock domain           
     always@(posedge rclk) 
        begin   
            if(!rst_bar)
                begin
                    Wr_ptr_syn1_gray<={ptr_size{1'b0}};
                    Wr_ptr_syn2_gray<={ptr_size{1'b0}};
                end
            else
                begin
                    Wr_ptr_syn1_gray<=Wr_ptr_gray;
                    Wr_ptr_syn2_gray<=Wr_ptr_syn1_gray;
                 end
         end             
      // synchronising in write clock domain          
       always@(posedge wclk) 
        begin   
            if(!rst_bar)
                begin
                    Rd_ptr_syn1_gray<={ptr_size{1'b0}};
                    Rd_ptr_syn2_gray<={ptr_size{1'b0}};
                end
            else
                begin
                    Rd_ptr_syn1_gray<=Rd_ptr_gray;
                    Rd_ptr_syn2_gray<=Rd_ptr_syn1_gray;
                 end
         end      
    
 //--------------------------------------------------------------------------------------------------------------- 
   // FIFO full flag calculation 
         always@(*)
            begin
                FIFO_full_flg=(({~Wr_ptr_gray[ptr_size-1:ptr_size-2],Wr_ptr_gray[ptr_size-3:0]})==Rd_ptr_syn2_gray);
            end
            
   // FIFO empty flag calculation
            always@(*)
                begin
                    FIFO_empty_flg=(Wr_ptr_syn2_gray==Rd_ptr_gray);
                end      
 //----------------------------------------------------------------------------------------------------------------  
  
    
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
                        end              
                end
                
             else 
                begin   
                    if(write_en==1)  //Write condition true
                        begin
                           FIFO_buf[wr_ptr[ptr_size-2:0]]<=data_in; // Write the new data
                        end
                    
                end            
      
        end        
     
     // Write pointer operation
     
        always@(posedge wclk)
        begin
            if(!rst_bar)
                begin // Synchronous Active Low reset
                        wr_ptr<={ptr_size{1'b0}};
                end
                
             else 
                begin   
                    if(write_en==1)  //Write condition true
                        begin
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
                    DATA_out<={data_width{1'b0}};  // DATA out register reset
                end
            else 
                begin
                    if(read_en==1)  //Read condition true
                        begin
                           DATA_out<=FIFO_buf[rd_ptr[ptr_size-2:0]]; 
                        end
                   
                end
        end        
                
      //  read pointer operation
      
      always@(posedge rclk)
        begin     
            if(!rst_bar_sync2)
                begin
                    rd_ptr<={ptr_size{1'b0}};       // Read pointer reset  
                end
            else 
                begin
                    if(read_en==1)                  //Read condition true
                        begin  
                           rd_ptr<=rd_ptr+1;          // Increment the  read pointer
                        end
                    else 
                        begin 
                            rd_ptr<=rd_ptr;           // Do not increment the read pointer
                        end
                end
        end        
endmodule
