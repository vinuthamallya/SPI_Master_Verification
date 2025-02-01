# SPI_Master_Verification
Verified SPI_Master using System Verilog 

SPI is a serial peripheral interface , also known as 4 wire communication interface . It sends and recieves data bits serially .
There are 4 output pins in SPI - sclk , miso , mosi , cs/ss and the input pins are clk , rst , newd , din .
As we can see there are 2 clks in this SPI interface - one clk is controlled by master that is sclk and the data is transmitted according to sclk and the other clock is the main system clk which triggers the master .
In general , the frequency of sclk is equal to the frequency of main clk divided by 8 . i.e fsclk = fclk/8 ; in simple words it means that the sclk will be high for 4 clk ticks and low for next 4 clk ticks - this is controlled by master.
MOSI - Master sends out the data to Slave 
MISO - Master takes the input from Slave / Slave sends out the data to master .
CS/SS - Chipsel or Slavesel - Master decides which slave is to be enabled to recieve data from Master , by default SS is 1 and is made 0 by master at the time of data transmission.
newd - signal to indicate if there is a new data available at din port .

Working -
Whenever there is a new data , the newd signal is made 1 , CS is made 0 and data begins to be transmitted serially bit by bit at posedge of sclk . This purely on the master side .

There are 4 different modes in which SPI master sends data but here I have taken a simple SPI interface for verification.
