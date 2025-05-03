LIBRARY 	ieee;
USE		ieee.std_logic_1164.all, ieee.numeric_std.all;

ENTITY de10lite IS
	PORT(	
		CLOCK_50	: 	IN			std_logic;
		KEY		: 	IN 		std_logic_vector( 1 DOWNTO 0 );
		SW			: 	IN 		std_logic_vector( 9 DOWNTO 0 );
		LEDR		: 	OUT		std_logic_vector( 9 DOWNTO 0 );
		SEGM		:	OUT		std_logic_vector( 7 DOWNTO 0 );
		GPIO_24         : IN  std_logic;  --RX
      GPIO_25         : OUT std_logic;  --TX
		UP			: IN 			std_logic;
		DOWN		: IN 			std_logic;
		BLEFT		: IN 			std_logic;
		BRIGHT	: IN 			std_logic;
		DIP1		: IN 			std_logic;
		DIP2		: IN 			std_logic;
		DIP3		: IN 			std_logic;
		DIP4		: IN 			std_logic;
		LEDROJO	: OUT			std_logic;
		LEDVERDE	: OUT			std_logic;
		SEG_DECENAS     : OUT std_logic_vector( 7 downto 0 );
      SEG_UNIDADES: OUT std_logic_vector( 7 downto 0 )
	);
END de10lite;

ARCHITECTURE Structural OF de10lite IS	
	
	component gumnut_with_mem IS
		generic ( 
			IMem_file_name : string := "gasm_text.dat";
			DMem_file_name : string := "gasm_data.dat";
         debug : boolean := false );
		port ( 
			clk_i : in std_logic;
         rst_i : in std_logic;
         -- I/O port bus
         port_cyc_o : out std_logic;
         port_stb_o : out std_logic;
         port_we_o : out std_logic;
         port_ack_i : in std_logic;
         port_adr_o : out unsigned(7 downto 0);
         port_dat_o : out std_logic_vector(7 downto 0);
         port_dat_i : in std_logic_vector(7 downto 0);
         -- Interrupts
         int_req : in std_logic;
         int_ack : out std_logic );
	end component gumnut_with_mem;
	
	COMPONENT uart IS
        GENERIC(
            clk_freq    :   integer     := 50_000_000;  --frequency of system clock in Hertz
            baud_rate   :   integer     := 115_200;     --data link baud rate in bits/second
            os_rate     :   integer     := 16;          --oversampling rate to find center of receive bits (in samples per baud period)
            d_width     :   integer     := 8;           --data bus width
            parity      :   integer     := 0;           --0 for no parity, 1 for parity
            parity_eo   :   std_logic   := '0');        --'0' for even, '1' for odd parity
        PORT(
            clk     :   IN  std_logic;                      --system clock
            reset_n :   IN  std_logic;                      --ascynchronous reset
            tx_ena  :   IN  std_logic;                      --initiate transmission
            tx_data :   IN  std_logic_vector(d_width-1 DOWNTO 0); --data to transmit
            rx      :   IN  std_logic;                      --receive pin
            rx_busy :   OUT std_logic;                      --data reception in progress, LEDR(9)
            rx_error:   OUT std_logic;                      --start, parity, or stop bit error detected
            rx_data :   OUT std_logic_vector(d_width-1 DOWNTO 0); --data received
            tx_busy :   OUT std_logic;                      --transmission in progress, LEDR(8)
            tx      :   OUT std_logic);                     --transmit pin
	END COMPONENT;

	COMPONENT debounce IS
	  PORT (  Clock       :   IN          STD_LOGIC;
				 button      :   IN          STD_LOGIC;
				 debounced   :   BUFFER  STD_LOGIC);
	END COMPONENT;

	COMPONENT seg7_decoder IS
	  PORT(
			bin : IN std_logic_vector(3 DOWNTO 0); -- número de 0 a 9
			seg : OUT std_logic_vector(7 DOWNTO 0) -- segmentos: a,b,c,d,e,f,g
	  );
	END COMPONENT;
	
	SIGNAL clk_i, rst_i, rst_uart: std_logic; 
	SIGNAL port_cyc_o, port_stb_o, port_we_o, port_ack_i:	std_logic;
	SIGNAL port_adr_o:	unsigned(7 downto 0);
	SIGNAL port_dat_o, port_dat_i:	std_logic_vector(7 downto 0);
	SIGNAL int_req, int_ack: std_logic;
	
	SIGNAL switches_botones	: std_logic_vector(7 downto 0);
	SIGNAL botones  : std_logic_vector(3 DOWNTO 0);
	SIGNAL botones_prev : std_logic_vector(3 DOWNTO 0) := (others => '1');
	SIGNAL switches : std_logic_vector(3 DOWNTO 0);
	SIGNAL switches_prev : std_logic_vector(3 DOWNTO 0) := (others => '0');

	SIGNAL uart_rx_data  : std_logic_vector(7 downto 0);
	SIGNAL tx_data_signal : std_logic_vector(7 downto 0);
	SIGNAL tx_ena_signal  : std_logic;
	
	SIGNAL rx_busy_internal:   std_logic;
	SIGNAL rx_error_internal:  std_logic;
	SIGNAL tx_busy_internal:   std_logic;
	
	signal uart_counter : std_logic_vector(5 downto 0) := (others => '0');
	signal uart_led_verde : std_logic;
	signal uart_led_rojo : std_logic;
	
	SIGNAL counter_internal: unsigned(7 downto 0);
	SIGNAL unidades_internal : std_logic_vector(3 DOWNTO 0);
   SIGNAL decenas_internal   : std_logic_vector(3 DOWNTO 0);
	
	signal tx_state : std_logic := '0';
	

BEGIN
	
	clk_i 		<= CLOCK_50;
	rst_i 		<= not KEY( 0 );
	rst_uart		<= KEY(0);
	port_ack_i	<= '1';
	
	botones  <= not UP & not DOWN & not BLEFT & not BRIGHT;
	switches <= not DIP1 & not DIP2 & not DIP3 & not DIP4;
	switches_botones <= switches & botones;
	
	
	gumnut : 		COMPONENT gumnut_with_mem 
							PORT MAP(
								clk_i,
								rst_i,
								port_cyc_o,
								port_stb_o,
								port_we_o,
								port_ack_i,
								port_adr_o( 7 DOWNTO 0 ),
								port_dat_o( 7 DOWNTO 0 ),
								port_dat_i( 7 DOWNTO 0 ),
								int_req,
								int_ack
								);			

	uart_0  : uart      PORT MAP( 
								clk_i, 
								rst_uart, 
								tx_ena_signal,
								tx_data_signal,
								GPIO_24,
								rx_busy_internal,
								rx_error_internal,
								uart_rx_data,
								tx_busy_internal,
								GPIO_25
								);
								
----GUMNUT PROCESSES

	--Botones y switches
	PROCESS(clk_i, rst_i)
	BEGIN
		 IF rst_i = '1' THEN
			  port_dat_i <= (OTHERS => '0');
		 ELSIF rising_edge(clk_i) THEN
			  IF port_cyc_o = '1' AND port_stb_o = '1' AND port_we_o = '0' THEN
					CASE port_adr_o IS
						WHEN 	x"02" =>  -- botones + switches
						  port_dat_i <= switches_botones;
						WHEN x"04" =>  -- uart_counter (6 bits)
                    port_dat_i <= "00" & uart_counter;
						WHEN "00000110" =>  -- uart_led verde
                    port_dat_i <= "0000000" & uart_led_verde;
						WHEN "00000111" =>  -- uart_led rojo
                    port_dat_i <= "0000000" & uart_led_rojo;
						WHEN OTHERS =>
						  port_dat_i <= (OTHERS => '0');
					END CASE;
			  END IF;
		 END IF;
	END PROCESS;
	

	-- send to PC via UART
	

	process(clk_i, rst_i)
	begin
		 if rst_i = '1' then
			  tx_data_signal <= (others => '0');
			  tx_ena_signal <= '1';
			  tx_state <= '0';
		 elsif rising_edge(clk_i) then
			  case tx_state is
					when '0' =>
						 if port_cyc_o = '1' 
							 and port_stb_o = '1' 
							 and port_we_o = '1' 
							 and port_adr_o = "00000101" then
							  tx_data_signal <= port_dat_o;
							  tx_ena_signal <= '0';
							  tx_state <= '1';
						 end if;
					when '1' =>
						 tx_ena_signal <= '1';
						 tx_state <= '0';
			  end case;
		 end if;
	end process;


	

	
------UART PROCESSES

	PROCESS(clk_i, rst_i)
	BEGIN
		 IF rst_i = '1' THEN
			  uart_counter <= (others => '0');
			  uart_led_verde <=  '0';
			  uart_led_rojo <='0';
		 ELSIF rising_edge(clk_i) THEN
			  -- Separate the received UART data
			  uart_counter <= uart_rx_data(5 downto 0);  -- top 6 bits
			  uart_led_verde <= uart_rx_data(7);     -- bottom 2 bits
			  uart_led_rojo <= uart_rx_data(6);     -- bottom 2 bits
		 END IF;
	END PROCESS;
	
	
	
	process(clk_i, rst_i)
	begin
		if rst_i = '1' then
			SEG_UNIDADES <= "11000000";  -- apagado
			SEG_DECENAS <= "11000000";  -- apagado
			decenas_internal <= (OTHERS => '0');
			unidades_internal <= (OTHERS => '0');
		elsif rising_edge(clk_i) then
			if port_adr_o = "00000000" 
				and 
				port_cyc_o = '1' 
				and 
				port_stb_o = '1' 
				and 
				port_we_o = '1' 
				then
				
				counter_internal <= unsigned(port_dat_o);
				
				unidades_internal <= std_logic_vector(counter_internal MOD 10)(3 DOWNTO 0);
				decenas_internal  <= std_logic_vector(counter_internal / 10)(3 DOWNTO 0);
				
				case unidades_internal(3 downto 0) is
					 when "0000" => SEG_UNIDADES <= "11000000"; -- 0
					 when "0001" => SEG_UNIDADES <= "11111001"; -- 1
					 when "0010" => SEG_UNIDADES <= "10100100"; -- 2
					 when "0011" => SEG_UNIDADES <= "10110000"; -- 3
					 when "0100" => SEG_UNIDADES <= "10011001"; -- 4
					 when "0101" => SEG_UNIDADES <= "10010010"; -- 5
					 when "0110" => SEG_UNIDADES <= "10000010"; -- 6
					 when "0111" => SEG_UNIDADES <= "11111000"; -- 7
					 when "1000" => SEG_UNIDADES <= "10000000"; -- 8
					 when "1001" => SEG_UNIDADES <= "10011000"; -- 9
					 when others => SEG_UNIDADES <= "11000000"; -- apagado o inválido
				end case;
				
				case decenas_internal(3 downto 0) is
					 when "0000" => SEG_DECENAS <= "11000000"; -- 0
					 when "0001" => SEG_DECENAS <= "11111001"; -- 1
					 when "0010" => SEG_DECENAS <= "10100100"; -- 2
					 when "0011" => SEG_DECENAS <= "10110000"; -- 3
					 when "0100" => SEG_DECENAS <= "10011001"; -- 4
					 when "0101" => SEG_DECENAS <= "10010010"; -- 5
					 when "0110" => SEG_DECENAS <= "10000010"; -- 6
					 when "0111" => SEG_DECENAS <= "11111000"; -- 7
					 when "1000" => SEG_DECENAS <= "10000000"; -- 8
					 when "1001" => SEG_DECENAS <= "10011000"; -- 9
					 when others => SEG_DECENAS <= "11000000"; -- apagado o inválido
				end case;
				
			elsif port_adr_o = "00000010" 
				and 
				port_cyc_o = '1' 
				and 
				port_stb_o = '1' 
				and 
				port_we_o = '1' 
				then
				LEDROJO <= port_dat_o(0);
				
			elsif port_adr_o = "00000011" 
				and 
				port_cyc_o = '1' 
				and 
				port_stb_o = '1' 
				and 
				port_we_o = '1' 
				then
				LEDVERDE <= port_dat_o(0);
				
			end if;
		 end if;
	end process;

	
		
END Structural;