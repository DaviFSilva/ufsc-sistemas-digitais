LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE std.env.finish;

ENTITY fsm_rps_tb IS
END ENTITY;

ARCHITECTURE testbench OF fsm_rps_tb IS
    SIGNAL clk, rst_a, ok : STD_LOGIC := '0';
    SIGNAL play, winner : std_logic_vector(1 DOWNTO 0);
    CONSTANT period : TIME := 10 ns;

    -- play encoding: 01=scissors, 10=rock, 11=paper
    -- winner encoding: 00=waiting, 01=P1, 10=P2, 11=draw
BEGIN
    clk <= NOT clk AFTER period/2;

    duv : ENTITY work.fsm_rps(arch)
          PORT MAP(clk=>clk, rst_a=>rst_a, ok=>ok, play=>play, winner=>winner);

    estimulos : PROCESS IS
        PROCEDURE tick IS
        BEGIN
            WAIT UNTIL falling_edge(clk);
        END PROCEDURE;

        PROCEDURE hard_reset IS
        BEGIN
            rst_a <= '1'; ok <= '0'; play <= "00";
            tick;
            ASSERT winner = "00"
                REPORT "After reset, expected WAIT_P1 (winner=00)" SEVERITY error;
            rst_a <= '0';
        END PROCEDURE;

        -- One confirmed play (ok pulse high for one cycle), then release ok.
        PROCEDURE confirm(CONSTANT move : std_logic_vector(1 DOWNTO 0)) IS
        BEGIN
            ok <= '1'; play <= move;
            tick;
            ok <= '0'; play <= "00";
        END PROCEDURE;

        PROCEDURE expect_wait(CONSTANT msg : string) IS
        BEGIN
            ASSERT winner = "00" REPORT msg SEVERITY error;
        END PROCEDURE;

        PROCEDURE expect_result(
            CONSTANT expected : std_logic_vector(1 DOWNTO 0);
            CONSTANT msg : string
        ) IS
        BEGIN
            ASSERT winner = expected REPORT msg SEVERITY error;
        END PROCEDURE;

        -- From a result state, press ok to return to WAIT_P1.
        PROCEDURE soft_return IS
        BEGIN
            ok <= '1'; play <= "00";
            tick;
            ok <= '0';
            expect_wait("After soft return, expected WAIT_P1 (winner=00)");
        END PROCEDURE;

        -- Full game: P1 move, then P2 move, check winner, soft return.
        PROCEDURE play_game(
            CONSTANT p1 : std_logic_vector(1 DOWNTO 0);
            CONSTANT p2 : std_logic_vector(1 DOWNTO 0);
            CONSTANT expected : std_logic_vector(1 DOWNTO 0);
            CONSTANT msg : string
        ) IS
        BEGIN
            confirm(p1);
            expect_wait("After P1, expected waiting for P2 (winner=00)");
            confirm(p2);
            expect_result(expected, msg);
            soft_return;
        END PROCEDURE;
    BEGIN
        REPORT "Iniciando teste completo da FSM RPS..." SEVERITY note;

        hard_reset;

        -- Hold in WAIT_P1 while ok=0
        ok <= '0'; play <= "01";
        tick;
        expect_wait("ok=0 must keep WAIT_P1");

        -- Invalid play with ok=1 stays in WAIT_P1
        ok <= '1'; play <= "00";
        tick;
        ok <= '0';
        expect_wait("play=00 with ok=1 must keep WAIT_P1");

        ------------------------------------------------------------------
        -- P1 = scissors (01)
        ------------------------------------------------------------------
        play_game("01", "01", "11", "SC vs SC -> DRAW");
        play_game("01", "10", "10", "SC vs RO -> P2_WINS");
        play_game("01", "11", "01", "SC vs PA -> P1_WINS");

        ------------------------------------------------------------------
        -- P1 = rock (10)
        ------------------------------------------------------------------
        play_game("10", "01", "01", "RO vs SC -> P1_WINS");
        play_game("10", "10", "11", "RO vs RO -> DRAW");
        play_game("10", "11", "10", "RO vs PA -> P2_WINS");

        ------------------------------------------------------------------
        -- P1 = paper (11)
        ------------------------------------------------------------------
        play_game("11", "01", "10", "PA vs SC -> P2_WINS");
        play_game("11", "10", "01", "PA vs RO -> P1_WINS");
        play_game("11", "11", "11", "PA vs PA -> DRAW");

        ------------------------------------------------------------------
        -- Hold in result state while ok=0, then soft return
        ------------------------------------------------------------------
        confirm("01");
        confirm("01");
        expect_result("11", "Setup DRAW for hold test");
        ok <= '0'; play <= "00";
        tick;
        expect_result("11", "ok=0 must keep DRAW");
        soft_return;

        ------------------------------------------------------------------
        -- Hard reset from mid-game
        ------------------------------------------------------------------
        confirm("10");
        expect_wait("After P1 rock, waiting for P2");
        hard_reset;

        WAIT FOR period;
        REPORT "Final do teste: OK" SEVERITY note;
        finish;
    END PROCESS;
END ARCHITECTURE;
