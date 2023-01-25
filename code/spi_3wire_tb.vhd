---------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-----------------------
 
ENTITY spi_3wire_tb IS
END spi_3wire_tb;
 
--------------------------
 
ARCHITECTURE behavior OF spi_3wire_tb IS 
 
    ---Inputs
   signal CLK_SYS : std_logic := '0';
   signal SCLK 	: std_logic := '0';
   signal Start 	: std_logic := '0';
   signal Data_In : std_logic_vector(47 downto 0) := (others => '0');

	---BiDirs
   signal SDIO 	: std_logic;

 	---Outputs
   signal CS_n 	: std_logic;
   signal RW_CTRL 	: std_logic;
	
	--- Internal Signal
	signal SCLK_Start     : std_logic := '0';
	
   ---Clock period definitions																									   	--set clock cycle
   constant CLK_SYS_period : time := 40 ns;																	
   constant SCLK_period    : time := 40 ns;
	
	BEGIN
 
	--- Instantiate the Unit Under Test (UUT)
   uut: entity work.spi_3wire PORT MAP (
          CLK_SYS => CLK_SYS,
          SCLK    => SCLK,
          Start   => Start,
          Data_In => Data_In,
          CS_n    => CS_n,
          RW_CTRL  => RW_CTRL,
          SDIO    => SDIO
        );

	--- CLK_SYS generator
	CLK_SYS_Pro :process
   begin
		CLK_SYS <= '0';
		wait for CLK_SYS_period/2;
		CLK_SYS <= '1';
		wait for CLK_SYS_period/2;
   end process CLK_SYS_Pro;
 --- SCLK_Start generator
	SCLK_Start_Pro :process
	begin
		SCLK_Start <= '0','1' after 	300ns;																							--set sclk
   wait;
	end process SCLK_Start_Pro;
	---

	--- SCLK Generate
	SCLK_Pro : process
	begin
		---
		if(SCLK_Start = '1') then
			---
			SCLK <= '0';
			wait for SCLK_period/2;
			SCLK <= '1';
			wait for SCLK_period/2;
			---
		else
			---
			SCLK <= '0';
			wait until SCLK_Start = '1';
			---
		end if;
		---
	end process SCLK_Pro;
	---
	
	--- Start generator
	Start_Pro :process
	begin
		---
			Start  <= '0', '1' after 	335ns, '0' after   375ns, '1' after  1455ns, '0' after  1495ns,			--set start, send pulse when is idle state
							   '1' after  3215ns, '0' after  3255ns, '1' after  4775ns, '0' after  4815ns;
	wait;
	
	end process start_Pro;
	
	--- data_In_generator
	Data_In_Pro:process
	begin
		---
		Data_In <= "000000000000000000011000000000000000000000000000",								--write one byte data=0x18 in address 0x00 for config SPI
				     "001000000000100000000000000000010000000000000000" after 1470ns,			--write two byte data=0x00,0x01 in address 0x08,0x09 for set clock and power mode
					  "100000000000000100000000000000000000000000000000" after 3230ns,			--read one byte from address = 0x01
					  "010000000001011000000000000000000000010000000000" after 4790ns;			--write 3 byte in address=0x16,0x17,x018

		wait;
		---
	end process Data_In_Pro;

 --- SDIO genarator
 SDIO <= 'Z' when RW_CTRL = '0' else '1' 						 	 , '0' after SCLK_period*1,	--data that's read =0x89
												 '1' after SCLK_period*4 , '0' after SCLK_period*5,
												 '1' after SCLK_period*7 ;

END;
