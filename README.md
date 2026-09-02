# Asynchronous-FIFO-<br>
Asynchronous FIFO design and Verification project<br>
Tool:Xilinx Vivado 2024.2


1/8/2026 
--------
Basics about Asynchronous FIFO design studied <br>
Analysed The FIFO empty and FIFO full flags   <br>
Designed logic for FIFO empty and FIFO full flags <br>



Code updated in the branch = 'Design'


22/8/2026 
--------
Gray coded CDC handled <br>
Reconversion logic studied -->  is it really needed ? <br>
Read and write operations handled  <br>
Ptr_size=Addr_size+1 added       <br>


Code updated in the branch = 'Design'


23/8/2026 
---------
Gray coded CDC handled <br>
Pointers comapred in gray coded version on both read and write domain<br>
Reset signal synchronized from write domain to read domain<br>
(Is it really the correct way??)<br>


Code updated in the branch = 'Design'



2/9/2026
--------
Added synchronous reset to both read and write domain <br>
Asynchronous assertion and synchronous deassertion implemented<br>
Initial design of RTL is finished <br>

Code updated in the branch = 'Design'

Stages<br>
----------
1. RTL design
2. Verification using System verilog Assertions( Need to Study what are Assertions )
3. Synthesis
4. Timing Verification
5. FPGA implementation
6. AXI wrapping (Phase 2 of the project)
