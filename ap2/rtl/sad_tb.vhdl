library IEEE;
use IEEE.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;

use work.sad_tb_test_cases.all;
use work.sad_pack.datapath_configuration_t;
use std.env.finish;

entity sad_tb is
    generic (
        TEST_UP_TO: natural := 5;
        bits_per_sample: positive := 8
    );
end sad_tb;

architecture tb of sad_tb is
    constant period : TIME := 20 ns;

    constant sad_filename: string := "testing_sads_" & positive'image(bits_per_sample) & ".dat";
    
    constant CFG : datapath_configuration_t := (
        bits_per_sample   => bits_per_sample,
        samples_per_block => 64,
        parallel_samples  => 1
    );
    constant B   : natural := CFG.bits_per_sample;
    constant N   : natural := CFG.samples_per_block;
    constant P   : natural := CFG.parallel_samples;


    signal clk        : std_logic := '0'; -- ck
    signal rst_a      : std_logic;
    signal enable     : std_logic;
    signal sample_ori : std_logic_vector(B * P - 1 downto 0); -- Mem_A[end]
    signal sample_can : std_logic_vector(B * P - 1 downto 0); -- Mem_B[end]
    signal read_mem   : std_logic;      -- read
    signal address    : std_logic_vector(integer(ceil(log2(real(N) / real(P)))) - 1 downto 0); -- end
    signal sad_value  : std_logic_vector(integer(ceil(log2(real(N)))) + B - 1 downto 0); -- SAD
    signal done       : std_logic;      -- pronto


    signal test_inputs  : test_cases_inputs_t(address(address'range), sad_value(sad_value'range));
    signal test_outputs : test_cases_output_t(sample_ori(sample_ori'range), sample_can(sample_can'range));

begin

    -- Connect DUV
    DUV : entity work.sad(structure)
        generic map(
            bits_per_sample   => B,     -- número de bits por amostra
            samples_per_block => N,     -- número de amostras por bloco
            parallel_samples  => P      -- número de amostras de cada bloco lidas em paralelo
        )
        port map(
            clk        => clk,
            enable     => enable,
            rst_a      => rst_a,
            sample_ori => sample_ori,
            sample_can => sample_can,
            read_mem   => read_mem,
            address    => address,
            sad_value  => sad_value,
            done       => done
        );

    -- geracao clock
    clk <= not clk after period / 2;

    -- io mapping
    test_inputs.clk       <= clk;
    test_inputs.done      <= done;
    test_inputs.read_mem  <= read_mem;
    test_inputs.address   <= address;
    test_inputs.sad_value <= sad_value;

    sample_ori <= test_outputs.sample_ori;
    sample_can <= test_outputs.sample_can;
    enable     <= test_outputs.enable;
    rst_a      <= test_outputs.rst_a;

    process
        variable errors : natural := 0;
        variable current_test_index : natural := 0;

        procedure maybe_finish(variable test_index: inout natural; variable number_of_errors: natural) is
        begin
            if test_index >= TEST_UP_TO then
                if number_of_errors > 0 then
                    report "Foram detectados erros na simulação. Verifique os e corrija os erros listados acima."
                    severity failure;
                else
                    report "Simulação executada sem erros até o teste " & natural'image(test_index) & "." severity note;
                end if;
        
                finish;
            end if;
            test_index := test_index + 1;
        end procedure;
    begin

        -- TEST SUITE 0:
        -- test to check if done is active in the initial state
        test_initial_state_has_done_active(
            inputs => test_inputs,
            outputs => test_outputs,
            errors => errors
        );
        maybe_finish(test_index => current_test_index, number_of_errors=>errors);
        -- END OF TEST SUITE 0 --

        -- TEST SUITE 1:
        -- test to check if done is not active after leaving the initial state
        test_after_init_the_architecture_leaves_the_initial_state(
            inputs => test_inputs,
            outputs => test_outputs,
            errors => errors
        );
        maybe_finish(test_index => current_test_index, number_of_errors=>errors);
        -- END OF TEST SUITE 1 --

        -- TEST SUITE 2:
        -- test to check if the architecture leaves the initial state and goes back to it 
        -- after the expected number of clock cycles
        test_architecture_takes_the_expected_number_of_cycles(
            inputs => test_inputs,
            outputs => test_outputs,
            errors => errors,
            CFG => CFG
        );
        maybe_finish(test_index => current_test_index, number_of_errors=>errors);
        -- END OF TEST SUITE 2 --

        -- TEST SUITE 3:
        -- two tests to check:
        -- 1) if the correct number of read_mems are issued
        test_correct_number_of_read_mems(
            inputs => test_inputs,
            outputs => test_outputs,
            errors => errors,
            CFG => CFG
        );

        -- 2) if the correct sequence of addresses are issued
        test_correct_sequence_of_address(
            inputs => test_inputs,
            outputs => test_outputs,
            errors => errors,
            CFG => CFG
        );
        maybe_finish(test_index => current_test_index, number_of_errors=>errors);
        -- END OF TEST SUITE 3 --

        -- TEST SUITE 4:
        -- Tests the corner cases
        -- 1) 0 to all inputs in all cycles results in SAD = 0
        test_all_inputs_0_must_result_in_0(
            inputs  => test_inputs,
            outputs => test_outputs,
            errors => errors,
            CFG => CFG
        );

        -- 2) MAX value to all inputs in all cycles should also result in SAD = 0
        test_all_inputs_max_must_result_in_0(
            inputs  => test_inputs,
            outputs => test_outputs,
            errors => errors,
            CFG => CFG
        );

        -- 3) One of the samples matrix is composed of MAX values and 
        -- the other one is composed of zeros. This should result in the
        -- maximum SAD value. 
        test_can_inputs_max_ori_zero_must_result_in_max_sad(
            inputs  => test_inputs,
            outputs => test_outputs,
            errors => errors,
            CFG => CFG
        );

        -- 4) Simular to 3, but changing which matrix has MAX and which has 0.
        -- This should also result in the maximum SAD value.
        test_can_inputs_zero_ori_max_must_result_in_max_sad(
            inputs  => test_inputs,
            outputs => test_outputs,
            errors => errors,
            CFG => CFG
        );
        maybe_finish(test_index => current_test_index, number_of_errors=>errors);
        -- END OF TEST SUITE 4 --


        -- TEST SUITE 5:
        tests_from_file(
            inputs=>test_inputs,
            outputs => test_outputs,
            errors => errors,
            CFG => CFG,
            filename=>sad_filename
        );

        -- Test suite 5 always finishes!
        if errors > 0 then
            report "Foram detectados erros na simulação. Verifique os e corrija os erros listados acima."
            severity failure;
        else
            report "Simulação executada sem erros." severity note;
        end if;

        finish;
    end process;

end tb;
