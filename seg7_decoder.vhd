LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

ENTITY seg7_decoder IS
    PORT(
        bin : IN std_logic_vector(3 DOWNTO 0); -- número de 0 a 9
        seg : OUT std_logic_vector(7 DOWNTO 0) -- segmentos: a,b,c,d,e,f,g
    );
END;

ARCHITECTURE behavior OF seg7_decoder IS
BEGIN
    PROCESS(bin)
    BEGIN
        CASE bin IS
            WHEN "0000" => seg <= "11000000"; -- 0
            WHEN "0001" => seg <= "11111001"; -- 1
            WHEN "0010" => seg <= "10100100"; -- 2
            WHEN "0011" => seg <= "10110000"; -- 3
            WHEN "0100" => seg <= "10011001"; -- 4
            WHEN "0101" => seg <= "10010010"; -- 5
            WHEN "0110" => seg <= "10000010"; -- 6
            WHEN "0111" => seg <= "11111000"; -- 7
            WHEN "1000" => seg <= "10000000"; -- 8
            WHEN "1001" => seg <= "10011000"; -- 9
            WHEN OTHERS => seg <= "11111111"; -- Apagar todo
        END CASE;
    END PROCESS;
END;
