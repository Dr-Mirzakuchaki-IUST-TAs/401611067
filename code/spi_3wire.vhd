-------------------------------------
--import library

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-----------------------------------------end import library

-----------------------------------------
--entity of spi module
entity spi_3wire is
    port (
        --input
        clk_sys         :in     std_logic;                                              --system clock
        sclk            :in     std_logic;                                              --module clock
        start           :in     std_logic;      
        data_in         :in     std_logic_vector(47 downto 0);

        --in/out
        sdio            :inout  std_logic;

        --out
        cs_n            :out    std_logic;
        rw_ctrl         :out    std_logic
    );
end spi_3wire;
------------------------------------end entity

------------------------------------
--architecture of spi module
architecture Behavioral of spi_3wire is
    
    --spi input/output register
    signal cs_n_int                  :std_logic                             :='1';
    signal rw_ctrl_int               :std_logic                             :='0';
    signal start_int                 :std_logic                             :='0';
    signal data_in_int               :std_logic_vector(31 downto 0)         :=(others=>'0');
    -----------------

    --spi internal signal
    type   instruction_data_path  is record
     inst_byte                      :std_logic_vector(15 downto 0);                        --signal for instruction section
	  rx_data                        :std_logic_vector(31 downto 0);                        --signal for data section 
    end record;
    
    signal data_path                 :instruction_data_path                 :=(inst_byte=>(others=>'0'),rx_data=>(others=>'0'));
    signal cnt_limit                 :unsigned (4 downto 0)                 :=(others=>'0');
    signal tx                        :std_logic                             :='Z';
    -----------------


    --spi counter
    signal bit_cnt                   :unsigned (4 downto 0)                 :="01111";
    -----------------

    --spi state
    type fsm is (idle , instruction , write_s ,read_s , delay_instruction , delay_read);
    signal state                     :fsm                                    :=idle;
    -----------------

begin

    cs_n         <=cs_n_int;
    rw_ctrl      <=rw_ctrl_int;
    sdio         <=tx when rw_ctrl_int ='0' else 'Z';                                         --combinational circiut for choose read or write

    process(clk_sys)
    begin
        if(rising_edge (clk_sys)) then
            data_in_int                       <=data_in(31 downto 0);                         --data
            data_path.inst_byte               <=data_in(47 downto 32);                        --instruction
            start_int                         <= start;                                       -- start operation

            ----
            case state is
                -----
                when idle =>                                                                  -- idle state ( no happen occure)
                  rw_ctrl_int                  <='0';
                  tx                           <='Z';
                  bit_cnt                      <="01111";                                     -- seven bit instruction
                  data_path.rx_data            <=(others=>'0');


                    if(start_int = '1') then                                                  -- ready next state to assign to the current state

                        state                  <=delay_instruction;
                        cs_n_int               <='0';
                       
                    else                                                                
                        state                  <= idle;                                        --stay in idle state
                        cs_n_int               <='1';
                        cnt_limit              <= (others=>'0');
                    end if;
                -----
                when delay_instruction =>                                                       -- for dont lose bit struction 
                  state                        <=instruction;                                   -- assign next state 
                  rw_ctrl_int                  <='0';
                  cs_n_int                     <='0';                                           --must be 0 so that chip gets active 
                  tx                           <=data_path.inst_byte(to_integer(bit_cnt));
                  bit_cnt                      <=bit_cnt - 1;
                  cnt_limit                    <=cnt_limit;
                  data_path.rx_data            <=(others=>'0');
                -----
                when instruction =>                                                              -- instruction state
                  rw_ctrl_int                  <='0';
                  cs_n_int                     <='0';
                  tx                           <=data_path.inst_byte(to_integer(bit_cnt));
                  data_path.rx_data            <=(others=>'0');
                  cnt_limit                    <=cnt_limit;
                
                    if(bit_cnt /= 0) then
                        state                  <=instruction;
                        bit_cnt                <=bit_cnt - 1;
                    else
                        bit_cnt                <=(others =>'1');
						
                        case to_integer(unsigned(data_path.inst_byte(14 downto 13))) is            -- choose number of data byte
                            when 0             =>  cnt_limit <= to_unsigned(24,5);
                            when 1             =>  cnt_limit <= to_unsigned(16,5);
                            when 2             =>  cnt_limit <= to_unsigned(8,5);
                            when others        =>  cnt_limit <= to_unsigned(0,5);
                        end case;

                        if(data_path.inst_byte(15) ='0')then                                       -- choose read or write                                        
                            state              <=write_s;
                        else
                            state              <=delay_read;
                        end if;
                    end if;
                -----
                when write_s =>                                                                    -- write state
                  rw_ctrl_int                  <='0';
                  cs_n_int                     <='0';
                  tx                           <=data_in_int(to_integer(bit_cnt));
                  data_path.rx_data            <=(others=>'0');
                    
                    if(bit_cnt /= cnt_limit)then                                                   -- to check all data's bit transfer
                        state                   <=write_s;
                        bit_cnt                 <=bit_cnt - 1;
                        cnt_limit               <=cnt_limit;

                    else
                        state                   <=idle;
                        bit_cnt                 <="01111";
                        cnt_limit               <=(others=>'0');
                    
                    end if;
                -----
                when delay_read =>                                                                -- for dont lose bit 
                  state                          <=read_s;
                  rw_ctrl_int                    <='1';
                  cs_n_int                       <='0';
                  tx                             <='Z';
                  bit_cnt                        <=bit_cnt - 1;
                  cnt_limit                      <=cnt_limit;
                  data_path.rx_data (to_integer(bit_cnt))  <=sdio;
                -----
                when others =>                                                                    -- read_s state
                  rw_ctrl_int                    <='1';
                  cs_n_int                       <='0';
                  tx                             <='Z';
                  cnt_limit                      <=cnt_limit;
                  data_path.rx_data (to_integer(bit_cnt))  <=sdio;
                    
                    if(bit_cnt /= cnt_limit)then                                                  -- to check all data's bit recive
                        state                    <=read_s;
                        bit_cnt                  <=bit_cnt - 1;

                    else
                        state                    <=idle;
                        bit_cnt                  <="01111";
                    
                    end if;

            end case;
        end if;
    end process;
end Behavioral;
-------------------------------------end architecture 
