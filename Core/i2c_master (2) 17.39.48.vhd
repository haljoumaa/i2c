library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master is 
    generic (
        SYS_CLK_FREQ_HZ : integer := 50_000_000;
        I2C_FREQ_HZ     : integer := 100_000);

    port 
    (
        clk           : in  std_logic;
        reset         : in  std_logic;

        slave_address : in  std_logic_vector(6 downto 0);
        data_in       : in  std_logic_vector(7 downto 0);
        data_out      : out std_logic_vector(7 downto 0);

        enable        : in  std_logic;
        continue      : in  std_logic;
        read_write    : in  std_logic;
        stop_signal   : in  std_logic;
        busy          : out std_logic;
        ack_error     : out std_logic;
        done          : out std_logic;
        ready         : out std_logic;
            
        scl           : out std_logic;
        sda           : inout std_logic
    );
	 
end entity;

architecture behavioral of i2c_master is

    -- Note: Not all internal signals are strictly necessary; they are included for clarity and code readability. 
    -- The design could be minimized by removing some of them if desired.

    constant scl_div_const : integer := (SYS_CLK_FREQ_HZ / (I2C_FREQ_HZ * 2 )) ;
    type state_type is (
        idle_state,
        start_state,
        address_state,
        address_ack_state,
        write_data_state,
        read_data_state,
        wait_write_state,
        slave_ack_state,
        master_ack_state,
        prep_stop_state,
        stop_state);

    -- fsm signals
    signal current_state        : state_type;

    --internal control signals 
    signal stop_transaction     : std_logic := '0';
    signal transaction_pending  : std_logic := '0';
    signal start_i2c            : std_logic := '0';
    signal byte_ready           : std_logic := '0';

    -- temporary registers 
    signal bit_count         : integer range 0 to 7 := 7;

    signal temp_addrRW       : std_logic_vector(7 downto 0);
    signal transfer_reg      : std_logic_vector(7 downto 0);
    signal receive_reg       : std_logic_vector(7 downto 0);
    
    --scl signals 
    signal scl_counter       : integer range 0 to scl_div_const - 1 := 0;
    signal scl_enable        : std_logic;
    signal scl_active        : std_logic;

    signal scl_internal      : std_logic;
    signal scl_internal_prev : std_logic;

    signal scl_fallingedge   : std_logic;
    signal scl_risingedge    : std_logic;

    -- sda constants/signals 
    signal sda_out           : std_logic;
	signal sda_oe            : std_logic;

    -- stop setuptime counter 
    constant C_SU_STO_STD    : integer := 200; 
    signal   su_count        : integer range 0 to C_SU_STO_STD := 0;


    
--processes
begin     
        -- stop control 
        process(clk)
        begin 
            if rising_edge(clk) then
                if (reset = '1') then
                    stop_transaction <= '0';
                
                elsif (stop_signal = '1') then
                    stop_transaction <= '1';
    
                elsif (current_state = stop_state) then
                    stop_transaction <= '0';
    
                end if ;
            end if ;
        end process;
    
        -- start control 
        process(clk) 
        begin 
            if rising_edge(clk) then
                if (reset = '1') then
                    start_i2c <= '0';
    
                elsif (enable = '1') then
                    start_i2c <= '1';
                
                elsif (current_state = start_state) then
                    start_i2c <= '0';
                end if ;
            end if ;
        end process;
    
        -- continue control  
        process(clk)
        begin 
            if rising_edge(clk) then
                if (reset = '1') then
                    transaction_pending <= '0';
    
                elsif (continue = '1') then
                    transaction_pending <= '1';
                
                elsif (scl_risingedge = '1' and current_state = slave_ack_state) then
                   transaction_pending <= '0';
    
                elsif (current_state = stop_state) then
                    transaction_pending <= '0';
                end if ;
            end if ;
        end process;
    
        -- ready handshake 
        process(clk)
        begin 
            if rising_edge(clk) then
                if (reset = '1')  then
                    byte_ready <= '0';
    
                elsif (scl_risingedge= '1' and current_state = slave_ack_state and sda = '0' and read_write = '0') then
                    byte_ready <= '1';
    
                elsif (transaction_pending = '1' or stop_transaction = '1' ) then
                    byte_ready <= '0';
                end if;
            end if;
        end process;
        ready <= byte_ready;


    --clock divison  
    process(clk)
    begin 
        if rising_edge(clk) then

            if (scl_counter  = scl_div_const - 1) then
                scl_counter <= 0;
                scl_enable <= '1';
            else 
                scl_counter <= scl_counter + 1;
                scl_enable <= '0';

            end if;
        end if;
    end process ; 

       -- scl toggel control 
       process(clk)
       begin
           if rising_edge(clk) then
               case current_state is
                    when idle_state | stop_state  =>
                        scl_active <= '0'; 
                       
                    when wait_write_state  =>
                       if (scl_fallingedge = '1') then
                            scl_active <= '0'; 
                        end if ;
                    when others =>
                        scl_active <= '1';    
               end case;
           end if;
       end process;

    --scl generation and edge detection 
    process(clk)
    begin 
        if rising_edge(clk) then
        
            --scl generation 
            if (reset = '1') then 
                scl_internal <= '1';
            elsif (scl_enable = '1' and scl_active = '1' ) then 
                scl_internal <= not scl_internal;
            else
                scl_internal <= scl_internal;
            end if;

             -- scl egde detection 
            if (scl_internal_prev = '0' and scl_internal = '1') then 
                scl_risingedge  <= '1';
                scl_fallingedge <= '0';

            elsif (scl_internal_prev = '1' and scl_internal = '0') then 
                scl_risingedge  <= '0';
                scl_fallingedge <= '1';

            else 
                scl_risingedge  <= '0';
                scl_fallingedge <= '0';

            end if;
            scl_internal_prev <= scl_internal;
        end if;
    end process; 
    scl <= scl_internal;

    -- sampling process
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                receive_reg <= (others => '0');
            elsif (scl_risingedge = '1') then 
                if (current_state = read_data_state) then
                    receive_reg(bit_count) <= sda;  
                end if;
            end if;
        end if;
    end process;

    --sda driving process 
    process(clk)
    begin 
        if rising_edge(clk) then
                if (reset = '1') then
                    sda_oe <= '0';
                    sda_out <= '1';

                elsif (scl_internal = '1' and scl_fallingedge = '0' and scl_risingedge = '0' ) then
                    if(current_state = start_state) then 
                        sda_out <= '0';
                        sda_oe  <= '1';

                    elsif (current_state = stop_state) then
                        sda_out <= '0';
                        sda_oe  <= '1';
                        if (su_count = C_SU_STO_STD) then
                            sda_out <= '1';
                            sda_oe  <= '0';  
                        else
                            su_count <= su_count + 1;
                        end if;

                    elsif (current_state = idle_state) then
                        sda_out <= '1';
                        sda_oe  <= '0';
                        
                    end if;

                elsif (scl_fallingedge = '0' and scl_risingedge='0' and scl_internal = '0' ) then 
                    case current_state is 

                    when address_state =>
                        sda_oe  <= NOT temp_addrRW(bit_count);
                        sda_out   <= '0';

                    when write_data_state =>
                        sda_oe <= NOT transfer_reg(bit_count);
                        sda_out   <= '0';

                    when slave_ack_state | read_data_state | address_ack_state | wait_write_state =>
                        sda_out <= '1';
                        sda_oe <= '0';

                    when prep_stop_state => 
                        sda_out <= '0';
                        sda_oe  <= '1';
                        su_count <= 0 ;

                    when master_ack_state =>
                        sda_out <= '1';
                        sda_oe <= '0'; 

                    when others =>
                        sda_out <= '1';
                        sda_oe <= '0';

                    end case;
                end if;
        end if;
    end process; 
    sda <= '0' when sda_oe = '1' and sda_out = '0' else 'Z';

    -- finite state machine
    process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                current_state <= idle_state;
                busy <= '0';
                done <= '0';
                ack_error <= '0';
                bit_count <= 7;
                data_out <= (others => '0');
            else
                -- Idle, start and wait states 
                if (scl_internal = '1') then
                    if (current_state = idle_state and start_i2c = '1') then
                        busy <= '1'; 
                        ack_error <= '0';
                        done <= '0';
                        transfer_reg <= data_in;
                        temp_addrRW <= slave_address & read_write;
                        current_state <= start_state;
                    elsif (current_state = stop_state) then
                        current_state <= idle_state;
                    end if;

                    
                elsif (scl_internal = '0') then
                    if (current_state = start_state) then
                        current_state <= address_state;
                    
                    elsif (current_state = wait_write_state) then 
                        if (transaction_pending = '1') then
                            current_state <= write_data_state; 
                        elsif (stop_transaction = '1') then
                            done <= '1'; 
                            current_state <= prep_stop_state;
                        else 
                            current_state <= wait_write_state; 
                        end if;
                    
                    end if ;
                end if;

                -- Transaction and ack states 
                if (scl_risingedge = '1') then
                    case current_state is 

                        when address_state =>
                            if (bit_count = 0) then 
                                current_state <= address_ack_state;
                            else 
                                bit_count <= bit_count - 1; 
                                current_state <= address_state;
                            end if;
                           
                        when address_ack_state =>
                            bit_count <= 7;
                            if (sda = '0') then
                                if (read_write = '0' ) then   
                                    current_state <= write_data_state;
                                else 
                                    current_state <= read_data_state;
                                end if; 
                            else 
                                ack_error <= '1';
                                done <= '1';
                                busy <= '0';
                                current_state <= prep_stop_state;
                            end if;
                            
                        when write_data_state => 
                            if (bit_count = 0) then 
                                current_state <= slave_ack_state;
                            else
                                bit_count <= bit_count - 1;
                                current_state <= write_data_state;
                            end if; 
                           
                        when read_data_state =>
                            if (bit_count = 0) then
                                current_state <= master_ack_state;
                            else
                                bit_count <= bit_count - 1;
                                current_state <= read_data_state;
                            end if;
                        
                        when slave_ack_state =>
                            if (sda = '0' and stop_transaction = '0') then
                                transfer_reg <= data_in;
                                bit_count <= 7;
                                if (read_write = '0') then
                                    current_state <= wait_write_state;
                                else 
                                    done <= '1';
                                    busy <= '0'; 
                                    current_state <= prep_stop_state;   
                                end if;

                            elsif (stop_transaction = '1') then
                                done <= '1';
                                busy <= '0';
                                current_state <= prep_stop_state;

                            else
                                ack_error <= '1';
                                done <= '1';
                                busy <= '0';
                                current_state <= prep_stop_state;
                            end if;
                            bit_count <= 7;
                    
                        when master_ack_state => 

                            data_out <= receive_reg;
                            if (sda_out = '0') then
                                current_state <= prep_stop_state;
                                done <= '1';
                                busy <= '0';
                            else 
                               ack_error<= '1';
                               done <= '1';
                               busy <= '0';
                               current_state <= prep_stop_state;
                            end if;

                        when prep_stop_state => 
                            current_state <= stop_state;
            
                        when stop_state =>
                            busy <= '0';
                            current_state <= idle_state;

                        when others =>
                            current_state <= idle_state;
                    end case;
                end if;
            end if;
        end if;
    end process;
end behavioral;