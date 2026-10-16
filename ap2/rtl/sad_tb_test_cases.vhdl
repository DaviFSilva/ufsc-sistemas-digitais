library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sad_pack.all;
use std.textio.all;

package sad_tb_test_cases is

    type test_cases_inputs_t is record
        clk : std_logic;
        done: std_logic;
        read_mem: std_logic;
        address: std_logic_vector;
        sad_value: std_logic_vector;
    end record;

    type test_cases_output_t is record
        rst_a      : std_logic;
        enable     : std_logic;
        sample_ori : std_logic_vector;
        sample_can : std_logic_vector;
    end record;

    procedure test_correct_number_of_read_mems(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    );

    procedure test_correct_sequence_of_address (
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    );

    procedure tests_from_file(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t;
        constant filename: string
    );

    procedure simple_test_case_same_value_at_inputs(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t;
        constant test_name: string;
        constant value_can: natural;
        constant value_ori: natural;
        constant expected_sad : natural
    );
    
    procedure test_all_inputs_0_must_result_in_0(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    );

    procedure test_all_inputs_max_must_result_in_0(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    );

    procedure test_can_inputs_max_ori_zero_must_result_in_max_sad(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    );

    procedure test_can_inputs_zero_ori_max_must_result_in_max_sad(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    );

    procedure test_initial_state_has_done_active(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural
    );

    procedure test_after_init_the_architecture_leaves_the_initial_state(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural
    );

    procedure test_architecture_takes_the_expected_number_of_cycles(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    );

end package sad_tb_test_cases;

package body sad_tb_test_cases is
    procedure test_architecture_takes_the_expected_number_of_cycles(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    ) is
        variable assert_result: boolean;
        constant EXPECTED_NUMBER_OF_CYCLES : natural := 3*((CFG.samples_per_block/CFG.parallel_samples)+1) + 1;
    begin
        outputs.enable <= '0';
        outputs.rst_a <= '1';

        wait until falling_edge(inputs.clk);
        outputs.rst_a <= '0';
        wait until falling_edge(inputs.clk);
        outputs.enable <= '1';

        for i in 0 to EXPECTED_NUMBER_OF_CYCLES-2 loop
            wait until falling_edge(inputs.clk);
            assert_result := inputs.done = '0';

            if not assert_result then
                errors := errors + 1;
            end if;

            assert assert_result
                    report "Erro ao testar o número de ciclos da arquitetura. Após o início " &
                    "(enable=1) o sinal done deveria ser 0 no ciclo " & natural'image(i+1) & 
                    ". Porém, o sinal done é " & std_logic'image(inputs.done) & "." severity error;
        end loop;

        wait until falling_edge(inputs.clk); -- reduces 1 from the expected number of cycles in the loop above

        assert_result := inputs.done = '1';

        if not assert_result then
            errors := errors + 1;
        end if;

        assert assert_result
                report "Erro ao testar o número de ciclos da arquitetura. Após " &
                natural'image(EXPECTED_NUMBER_OF_CYCLES) & " ciclos a arquitetura deveria voltar ao estado" 
                & "inicial e o sinal done deveria ser 1." severity error;

        outputs.enable <= '0';
        outputs.rst_a <= '1';
        wait until falling_edge(inputs.clk);
        outputs.rst_a <= '0';

    end procedure;

    procedure test_after_init_the_architecture_leaves_the_initial_state(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural
    ) is
        variable assert_result: boolean;
    begin
        outputs.enable <= '0';
        outputs.rst_a <= '1';

        wait until falling_edge(inputs.clk);
        outputs.rst_a <= '0';
        wait until falling_edge(inputs.clk);
        outputs.enable <= '1';
        wait until falling_edge(inputs.clk);

        assert_result := inputs.done = '0';

        if not assert_result then
            errors := errors + 1;
        end if;

        assert assert_result
                report "Erro ao testar o sinal done após iniciar a execução." &
                "Esperava-se que o sinal done passasse a valer 0. Porém, no ciclo seguinte ao " &
                "iniciar, o valor de done é " & std_logic'image(inputs.done) & "." severity error;

        wait until falling_edge(inputs.clk);

        outputs.enable <= '0';
        outputs.rst_a <= '1';
        wait until falling_edge(inputs.clk);
        outputs.rst_a <= '0';

    end procedure;

    procedure test_initial_state_has_done_active(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural
    ) is
        variable assert_result: boolean;
    begin
        outputs.enable <= '0';
        outputs.rst_a <= '0';

        wait until falling_edge(inputs.clk);
        outputs.rst_a      <= '1';
        wait until falling_edge(inputs.clk);

        assert_result := inputs.done = '1';

        if not assert_result then
            errors := errors + 1;
        end if;

        assert assert_result
                report "Erro ao testar o sinal done no estado inicial. " &
                "Esperava-se que o sinal done fosse valer 1 após um reset (que leva ao estado inicial). Porém, " &
                "o valor de done é " & std_logic'image(inputs.done) & "." severity error;

        wait until falling_edge(inputs.clk);

    end procedure;


    procedure tests_from_file(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t;
        constant filename: string
    ) is
        file stimulus_file : text open read_mode 
        is filename;
        variable stimulus_line: line;
        variable sample_ori, sample_can: natural range 0 to (2**CFG.bits_per_sample)-1;
        variable expected_sad : natural range 0 to (2**inputs.sad_value'length)-CFG.samples_per_block;
        variable number_of_errors : natural := errors;
        variable assert_result: boolean;
        constant number_of_read_loops : natural := CFG.samples_per_block/CFG.parallel_samples;
    begin

        outputs.enable <= '0';
        outputs.rst_a <= '0';

        wait until falling_edge(inputs.clk);
        outputs.rst_a      <= '1';
        wait until falling_edge(inputs.clk);
        outputs.rst_a      <= '0';
        wait until falling_edge(inputs.clk);
        outputs.enable     <= '1';

        while not endfile(stimulus_file) loop

            for temp in 0 to number_of_read_loops-1 loop
                wait until rising_edge(inputs.read_mem);
                
                read_inputs: for i in 0 to CFG.parallel_samples-1 loop
                    readline(stimulus_file, stimulus_line);
                    read(stimulus_line, sample_ori);
                    read(stimulus_line, sample_can);

                    outputs.sample_ori((i+1)*CFG.bits_per_sample-1 downto i*CFG.bits_per_sample) <= std_logic_vector(to_unsigned(sample_ori, CFG.bits_per_sample));
                    outputs.sample_can((i+1)*CFG.bits_per_sample-1 downto i*CFG.bits_per_sample) <= std_logic_vector(to_unsigned(sample_can, CFG.bits_per_sample));
                end loop;
            end loop;
            
            wait until rising_edge(inputs.done);
            wait until falling_edge(inputs.clk);

            readline(stimulus_file, stimulus_line);
            read(stimulus_line, expected_sad);

            assert_result := to_integer(unsigned(inputs.sad_value)) = expected_sad;

            if not assert_result then
                number_of_errors := number_of_errors+1;
            end if;
            assert assert_result
                report "Erro ao processar uma SAD do arquivo. O valor esperado na saída sad_value era " & 
                natural'image(expected_sad) & " (" & 
                to_string(to_unsigned(expected_sad, inputs.sad_value'length)) & "). Porém, o valor obtido foi " &
                natural'image(to_integer(unsigned(inputs.sad_value))) & "(" & 
                to_string(inputs.sad_value)
                & ")." severity error;
        end loop;

        outputs.enable   <= '0';

        wait until falling_edge(inputs.clk);

        errors := number_of_errors;

    end procedure;

    procedure test_correct_number_of_read_mems(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    ) is
        constant number_of_read_loops : natural := CFG.samples_per_block/CFG.parallel_samples;
        variable number_of_read_mems: natural := 0;
        variable already_done : boolean := false;
        variable passed_the_number_of_read_loops : boolean := false;
        variable assert_result : boolean;
        function get_causa(constant more_than_expected: boolean) return string is
        begin
            if more_than_expected then
                return "o número de leituras ultrapassou o esperado.";
            else
                return "o sinal done foi detectado antes do esperado (i.e., antes de atingir o número esperado de ativações de read_mem).";
            end if;
        end function get_causa;
    begin

    outputs.enable <= '0';
    outputs.rst_a <= '0';

    wait until falling_edge(inputs.clk);
    outputs.rst_a      <= '1';
    wait until falling_edge(inputs.clk);
    outputs.rst_a      <= '0';
    wait until falling_edge(inputs.clk);
    outputs.enable     <= '1';

    while (not already_done and not passed_the_number_of_read_loops) loop
        wait until rising_edge(inputs.done) or rising_edge(inputs.read_mem);
        if inputs.read_mem then
            number_of_read_mems := number_of_read_mems+1;
        end if;
        if inputs.done then
            already_done := true;
        end if;
        if number_of_read_mems > number_of_read_loops then
            passed_the_number_of_read_loops := true;
        end if;
    end loop;
    
    assert_result := number_of_read_mems = number_of_read_loops;

    if not assert_result then
        errors := errors+1;
    end if;

    assert assert_result
        report "Erro no número de read_mems. Esperava-se que fossem feitas " & 
        natural'image(number_of_read_loops) & "requisições de leitura à memória (read_mem=1)." &
        "porém, " & 
        get_causa(number_of_read_mems > number_of_read_loops)
         severity error;

    end procedure;


    procedure test_correct_sequence_of_address(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    ) is
        constant number_of_read_loops : natural := CFG.samples_per_block/CFG.parallel_samples;
        variable number_of_read_mems: natural := 0;
        variable already_done : boolean := false;
        variable error_address : boolean := false;
        variable assert_result : boolean;
        variable current_address : natural := 0;
    begin

    outputs.enable <= '0';
    outputs.rst_a <= '0';

    wait until falling_edge(inputs.clk);
    outputs.rst_a      <= '1';
    wait until falling_edge(inputs.clk);
    outputs.rst_a      <= '0';
    wait until falling_edge(inputs.clk);
    outputs.enable     <= '1';

    while (not already_done and not error_address) loop
        wait until rising_edge(inputs.done) or rising_edge(inputs.read_mem);
        if inputs.read_mem then
            number_of_read_mems := number_of_read_mems+1;
            
            assert_result := to_integer(unsigned(inputs.address)) = current_address;

            if not assert_result then
                error_address := true;
                errors := errors+1;
            end if;

            assert assert_result 
                report "Erro no endereço (address). Esperado " & 
                natural'image(current_address) & "(" & 
                to_string(to_unsigned(current_address, inputs.address'length))
                & "). Obtido " & 
                natural'image(to_integer(unsigned(inputs.address)))
                & "(" & 
                to_string(inputs.address)
                & ")." severity error;            

            current_address := current_address + 1 ;
                
        end if;
        if inputs.done then
            already_done := true;
        end if;
    end loop;
    
    assert_result := number_of_read_mems = number_of_read_loops;

    if not assert_result then
        errors := errors+1;
    end if;

    assert assert_result
        report "Error in the number of read_mems." severity error;

    end procedure;


    procedure simple_test_case_same_value_at_inputs(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t;
        constant test_name: string;
        constant value_can: natural;
        constant value_ori: natural;
        constant expected_sad : natural
    ) is 
        constant N : positive := CFG.bits_per_sample;
        constant P : positive := CFG.parallel_samples;
        variable assert_result : boolean;
    begin

        outputs.enable <= '0';
        outputs.rst_a <= '0';

        assign_sad_inputs: for i in 0 to P-1 loop
            outputs.sample_ori((i+1)*N-1 downto i*N) <= std_logic_vector(to_unsigned(value_ori, N));
            outputs.sample_can((i+1)*N-1 downto i*N) <= std_logic_vector(to_unsigned(value_can, N));
        end loop;

        wait until falling_edge(inputs.clk);
        outputs.rst_a      <= '1';
        wait until falling_edge(inputs.clk);
        outputs.rst_a      <= '0';
        wait until falling_edge(inputs.clk);
        outputs.enable     <= '1';
        wait until rising_edge(inputs.done);

        wait until falling_edge(inputs.clk);

        assert_result := inputs.sad_value = std_logic_vector(to_unsigned(expected_sad, inputs.sad_value'length));

        if not assert_result then
            errors := errors + 1;
        end if;
        
        assert assert_result
            report test_name & ": Erro no teste de casos limite. " &
                "Todas as amostras de A (sample_ori) foram mantidas com valor " & natural'image(value_ori) & " e " &
                "todas as amostras de B (sample_can) foram mantidas com valor " & natural'image(value_can) & 
                ". Neste caso, o valor esperado na saída sad_value era " & 
                natural'image(expected_sad) & " (" & 
                to_string(to_unsigned(expected_sad, inputs.sad_value'length)) & "). Porém, o valor obtido foi " &
                natural'image(to_integer(unsigned(inputs.sad_value))) & "(" & 
                to_string(inputs.sad_value)
                & ")." severity error;

        outputs.enable   <= '0';

        wait until falling_edge(inputs.clk);

    end procedure;


    procedure test_all_inputs_0_must_result_in_0(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    ) is 
    begin

        simple_test_case_same_value_at_inputs(
            inputs => inputs,
            outputs => outputs,
            errors => errors,
            CFG => CFG,
            test_name => "All inputs with value zero must result in SAD = 0.",
            value_can => 0,
            value_ori => 0,
            expected_sad => 0
        );

    end procedure;

    procedure test_all_inputs_max_must_result_in_0(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    ) is 
        constant MAX : positive := (2**CFG.bits_per_sample)-1;
    begin

        outputs.sample_ori <= std_logic_vector(to_unsigned(MAX, outputs.sample_ori'length));
        outputs.sample_can <= std_logic_vector(to_unsigned(MAX, outputs.sample_can'length));

        simple_test_case_same_value_at_inputs(
            inputs => inputs,
            outputs => outputs,
            errors => errors,
            CFG => CFG,
            test_name => "All inputs with max value must result in SAD = 0.",
            value_can => MAX,
            value_ori => MAX,
            expected_sad => 0
        );

    end procedure;

    procedure test_can_inputs_max_ori_zero_must_result_in_max_sad(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    ) is 
        constant MAX : positive := (2**CFG.bits_per_sample)-1;
        constant MAX_SAD : positive := (2**inputs.sad_value'length)-CFG.samples_per_block;
    begin

        simple_test_case_same_value_at_inputs(
            inputs => inputs,
            outputs => outputs,
            errors => errors,
            CFG => CFG,
            test_name => "Candidate inputs with max value and original with 0 must result in the maximum SAD value.",
            value_can => MAX,
            value_ori => 0,
            expected_sad => MAX_SAD
        );

    end procedure;

    procedure test_can_inputs_zero_ori_max_must_result_in_max_sad(
        signal inputs : in test_cases_inputs_t;
        signal outputs: out test_cases_output_t;
        variable errors: inout natural;
        constant CFG: datapath_configuration_t
    ) is 
        constant MAX : positive := (2**CFG.bits_per_sample)-1;
        constant MAX_SAD : positive := (2**inputs.sad_value'length)-CFG.samples_per_block;
    begin

        simple_test_case_same_value_at_inputs(
            inputs => inputs,
            outputs => outputs,
            errors => errors,
            CFG => CFG,
            test_name => "Candidate inputs with 0 and original with max value must result in the maximum SAD value.",
            value_can => 0,
            value_ori => MAX,
            expected_sad => MAX_SAD
        );

    end procedure;
end package body sad_tb_test_cases;
