LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE std.env.finish;

ENTITY fsm_rps_tb IS
END ENTITY;

ARCHITECTURE testbench OF fsm_rps_tb IS
    SIGNAL clk, rst_a, ok : STD_LOGIC := '0';
    SIGNAL play, winner : std_logic_vector(1 DOWNTO 0);
    CONSTANT period : TIME := 10 ns;
BEGIN
    clk <= NOT clk AFTER period/2;

    duv : ENTITY work.fsm_rps(arch)
          PORT MAP(clk=>clk, rst_a=>rst_a, ok=>ok, play=>play, winner=>winner);

    estimulos : PROCESS IS
    BEGIN
        REPORT "Iniciando teste..." SEVERITY note;
        REPORT "Testando FSM com 2 processos." SEVERITY note;

        rst_a <= '1'; ok <= '0'; play <= "00";
        WAIT UNTIL falling_edge(clk);

        rst_a <= '0'; ok <= '1'; play <= "01";
        WAIT UNTIL falling_edge(clk);
        ASSERT (winner = "00") REPORT "Estado SC_WAIT_P2, winner = 00"
        SEVERITY error;

        ok <= '1'; play <= "01";
        WAIT UNTIL falling_edge(clk);
        ASSERT (winner = "11") REPORT "Estado DRAW, winner = 11"
        SEVERITY error;

        rst_a <= '1'; ok <= '0'; play <= "00";
        WAIT UNTIL falling_edge(clk);
        ASSERT (winner = "00") REPORT "Estado WAIT_P1, winner = 00"
        SEVERITY error;

        rst_a <= '0'; ok <= '1'; play <= "01";
        WAIT UNTIL falling_edge(clk);
        ASSERT (winner = "00") REPORT "Estado SC_WAIT_P2, winner = 00"
        SEVERITY error;

        ok <= '1'; play <= "10";
        WAIT UNTIL falling_edge(clk);
        ASSERT (winner = "10") REPORT "Estado P2_WINS, winner = 10"
        SEVERITY error;

        rst_a <= '1'; ok <= '0'; play <= "00";
        WAIT UNTIL falling_edge(clk);
        ASSERT (winner = "00") REPORT "Estado WAIT_P1, winner = 00"
        SEVERITY error;

        WAIT FOR period;
        REPORT "Final do teste: OK" SEVERITY note;
        finish;
    END PROCESS;
END ARCHITECTURE;
