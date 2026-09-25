LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY fsm_rps IS
	PORT (
		clk : IN std_logic;
		rst_a : IN std_logic;
		ok : IN std_logic;
		play : IN std_logic_vector(1 DOWNTO 0);
		winner : OUT std_logic_vector(1 DOWNTO 0)
	);
END fsm_rps;

ARCHITECTURE arch OF fsm_rps IS
	TYPE state_t IS (WAIT_P1, SC_WAIT_P2, RO_WAIT_P2, PA_WAIT_P2, P1_WINS, DRAW, P2_WINS);
	SIGNAL CurrentState, NextState : state_t;
BEGIN
	NSL: PROCESS (ok, play, CurrentState)
	BEGIN
		CASE CurrentState IS
			WHEN WAIT_P1 =>
				IF ok = '0' THEN NextState <= WAIT_P1;
				ELSIF play = "01" THEN NextState <= SC_WAIT_P2;
				ELSIF play = "10" THEN NextState <= RO_WAIT_P2;
				ELSIF play = "11" THEN NextState <= PA_WAIT_P2;
				ELSE NextState <= WAIT_P1;
				END IF;
			WHEN SC_WAIT_P2 =>
				IF ok = '0' THEN NextState <= SC_WAIT_P2;
				ELSIF play = "01" THEN NextState <= DRAW;
				ELSIF play = "10" THEN NextState <= P2_WINS;
				ELSIF play = "11" THEN NextState <= P1_WINS;
				ELSE NextState <= SC_WAIT_P2;
				END IF;
			WHEN RO_WAIT_P2 =>
				IF ok = '0' THEN NextState <= RO_WAIT_P2;
				ELSIF play = "01" THEN NextState <= P1_WINS;
				ELSIF play = "10" THEN NextState <= DRAW;
				ELSIF play = "11" THEN NextState <= P2_WINS;
				ELSE NextState <= RO_WAIT_P2;
				END IF;
			WHEN PA_WAIT_P2 =>
				IF ok = '0' THEN NextState <= PA_WAIT_P2;
				ELSIF play = "01" THEN NextState <= P2_WINS;
				ELSIF play = "10" THEN NextState <= P1_WINS;
				ELSIF play = "11" THEN NextState <= DRAW;
				ELSE NextState <= PA_WAIT_P2;
				END IF;
			WHEN P1_WINS =>
				IF ok = '0' THEN NextState <= P1_WINS;
				ELSE NextState <= WAIT_P1;
				END IF;
			WHEN P2_WINS =>
				IF ok = '0' THEN NextState <= P2_WINS;
				ELSE NextState <= WAIT_P1;
				END IF;
			WHEN DRAW =>
				IF ok = '0' THEN NextState <= DRAW;
				ELSE NextState <= WAIT_P1;
				END IF;
		END CASE;
	END PROCESS NSL;

	State: PROCESS (clk, rst_a)
	BEGIN
		IF rst_a = '1' THEN CurrentState <= WAIT_P1;
		ELSIF (rising_edge(clk)) THEN
			CurrentState <= NextState; END IF;
	END PROCESS State;

	winner <= "01" WHEN CurrentState = P1_WINS ELSE
	          "10" WHEN CurrentState = P2_WINS ELSE
	          "11" WHEN CurrentState = DRAW ELSE
	          "00";
END arch;
