#!/usr/bin/env bash
#-------------------------------------------------------------------------------
#- MIT License
#-
#- Copyright (c) 2021 Timothy Stotts
#-
#- Permission is hereby granted, free of charge, to any person obtaining a copy
#- of this software and associated documentation files (the "Software"), to deal
#- in the Software without restriction, including without limitation the rights
#- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#- copies of the Software, and to permit persons to whom the Software is
#- furnished to do so, subject to the following conditions:
#-
#- The above copyright notice and this permission notice shall be included in
#- all copies or substantial portions of the Software.
#-
#- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#- SOFTWARE.
#-------------------------------------------------------------------------------

if [[ -z ${SRC_DIR} ]]; then
    SRC_DIR=".."
fi

function clean_work_dir () {
    rm -f *.o
    rm -f work-obj08.cf osvvm-obj08.cf osvvm_common-obj08.cf osvvm_axi4-obj08.cf osvvm_uart-obj08.cf
    rm -f fpga_serial_acl_tester_tb
    rm -f fpga_serial_acl_tester_testharness
}

function ghdl_analyze () {
    # std , worklib, path
    echo "ghdl -a --std=${1} --work=${2} -O2 ${3}"
    ghdl -a --std=${1} --work=${2} -O2 "${3}" || exit 1
}

function ghdl_elaborate () {
    # std, work unit
    echo "ghdl -e --std=08 -fsynopsys -frelaxed -O2 ${2}"
    ghdl -e --std=${1} -fsynopsys -frelaxed -O2 ${2} || exit 1
}

function ghdl_generate_optlist () {
    # std, work unit, vcd wave dump, wave list output
    echo "ghdl -r --std=${1} -fsynopsys -frelaxed ${2} ---vcd=${3} ---write-wave-opt=${4} --stop-time=1us"
    ghdl -r --std=${1} -fsynopsys -frelaxed ${2} --vcd=${3} --write-wave-opt=${4} --stop-time=1us || exit 1
}

function ghdl_run () {
    # std, work unit, wave dump, wave list
    echo "ghdl -r --std=${1} -fsynopsys -frelaxed ${2} --stop-time=100ms --vcd=${3} --read-wave-opt=${4}"
    ghdl -r --std=${1} -fsynopsys -frelaxed ${2} --stop-time=100ms --vcd=${3} --read-wave-opt=${4} || exit 1
}

function ghdl_run_batch () {
    # std, work unit, duration
    if [[ -z ${3} ]]; then
        echo "ghdl -r --std=${1} -fsynopsys -frelaxed ${2}"
        ghdl -r --std=${1} -fsynopsys -frelaxed ${2} || exit 1
    elif [[ -z ${4} ]]; then
        echo "ghdl -r --std=${1} -fsynopsys -frelaxed ${2} --stop-time=${3}"
        ghdl -r --std=${1} -fsynopsys -frelaxed ${2} --stop-time=${3} || exit 1
    elif [[ -z ${6} ]]; then
        echo "ghdl -r --std=${1} -fsynopsys -frelaxed ${2} --stop-time=${3} --read-wave-opt=${4}  --vcd=${5}"
        ghdl -r --std=${1} -fsynopsys -frelaxed ${2} --stop-time=${3} --read-wave-opt=${4} --vcd=${5} || exit 1        
    fi;
}

function compile_ossvm () {
    for filename in \
	ResolutionPkg.vhd \
        NamePkg.vhd \
	NameStorePkg.vhd \
        OsvvmGlobalPkg.vhd \
        \
        VendorCovApiPkg.vhd \
        \
        TranscriptPkg.vhd \
        TextUtilPkg.vhd \
        AlertLogPkg.vhd \
        \
        MessageListPkg.vhd \
        SortListPkg_int.vhd \
        RandomBasePkg.vhd \
        RandomPkg.vhd \
	RandomProcedurePkg.vhd \
        CoveragePkg.vhd \
        MemoryPkg.vhd \
        \
        ScoreboardGenericPkg.vhd \
        ScoreboardPkg_slv.vhd \
        ScoreboardPkg_int.vhd \
        \
	ResizePkg.vhd \
        TbUtilPkg.vhd \
        \
	ReportPkg.vhd \
	\
        OsvvmContext.vhd \
        ; do

        ghdl_analyze 08 osvvm "${SRC_DIR}/OSVVM/OsvvmLibraries/osvvm/${filename}"
    done
}

function compile_ossvm_common () {
    for filename in \
        StreamTransactionPkg.vhd \
        AddressBusTransactionPkg.vhd \
        AddressBusResponderTransactionPkg.vhd \
        AddressBusVersionCompatibilityPkg.vhd \
        ModelParametersPkg.vhd \
        FifoFillPkg_slv.vhd \
	InterruptHandler.vhd \
	InterruptHandlerComponentPkg.vhd \
        OsvvmCommonContext.vhd \
        ; do

        ghdl_analyze 08 OSVVM_Common "${SRC_DIR}/OSVVM/OsvvmLibraries/Common/src/${filename}"
    done
}

function compile_ossvm_axi4_common () {
    for filename in \
        Axi4LiteInterfacePkg.vhd \
        Axi4InterfacePkg.vhd \
        Axi4CommonPkg.vhd \
        Axi4ModelPkg.vhd \
        Axi4OptionsTypePkg.vhd \
        Axi4VersionCompatibilityPkg.vhd \
        ; do

        ghdl_analyze 08 osvvm_axi4 "${SRC_DIR}/OSVVM/OsvvmLibraries/AXI4/common/src/${filename}"
    done
}

# function compile_ossvm_axi4_axi4lite () {
#     for filename in \
#         Axi4LiteMasterComponentPkg.vhd \
#         Axi4LiteResponderComponentPkg.vhd \
#         Axi4LiteMemoryComponentPkg.vhd \
#         Axi4LiteMonitorComponentPkg.vhd \
#         Axi4LiteContext.vhd \
#         Axi4LiteMaster.vhd \
#         Axi4LiteMonitor_dummy.vhd \
#         Axi4LiteResponder_Transactor.vhd \
#         Axi4LiteMemory.vhd \
#         ; do

#         ghdl_analyze 08 osvvm_axi4 "${SRC_DIR}/OSVVM/OsvvmLibraries/AXI4/Axi4Lite/src/${filename}"
#     done
# }

# function compile_ossvm_axi4_axi4stream () {
#     for filename in \
#         AxiStreamOptionsPkg.vhd \
#         AxiStreamTbPkg.vhd \
#         AxiStreamTransmitter.vhd \
#         AxiStreamReceiver.vhd \
#         AxiStreamComponentPkg.vhd \
#         AxiStreamContext.vhd \
#         AxiStreamGenericSignalsPkg.vhd \
#         AxiStreamSignalsPkg_32.vhd \
#         ; do

#         ghdl_analyze 08 osvvm_axi4 "${SRC_DIR}/OSVVM/OsvvmLibraries/AXI4/AxiStream/src/${filename}"
#     done
# }

# function compile_ossvm_axi4_axi4 () {
#     for filename in \
#         Axi4MasterComponentPkg.vhd \
#         Axi4ResponderComponentPkg.vhd \
#         Axi4MemoryComponentPkg.vhd \
#         Axi4MonitorComponentPkg.vhd \
#         Axi4Context.vhd \
#         Axi4Master.vhd \
#         Axi4Monitor_dummy.vhd \
#         Axi4Responder_Transactor.vhd \
#         Axi4Memory.vhd \
#         ; do

#         ghdl_analyze 08 osvvm_axi4 "${SRC_DIR}/OSVVM/OsvvmLibraries/AXI4/Axi4/src/${filename}"
#     done
# }

function compile_ossvm_uart () {
    for filename in \
        UartTbPkg.vhd \
        ScoreboardPkg_Uart.vhd \
        UartTxComponentPkg.vhd \
        UartRxComponentPkg.vhd \
        UartContext.vhd \
        UartTx.vhd \
        UartRx.vhd \
        ; do

        ghdl_analyze 08 osvvm_uart "${SRC_DIR}/OSVVM/OsvvmLibraries/UART/src/${filename}"
    done
}

function compile_work () {
    for filename in \
        clock_divider.vhdl \
        clock_enable_divider.vhdl \
        arty_reset_synchronizer.vhdl \
        ext_interrupt_debouncer.vhdl \
        lcd_text_functions_pkg.vhdl \
        multi_input_debounce.vhdl \
        one_shot_fsm.vhdl \
        pulse_stretcher_synch.vhdl \
        \
        ssd_display.vhdl \
        thresh_presets_selector.vhdl \
        thresh_presets_pkg.vhdl \
        \
        acl_tester_fsm.vhdl \
        adxl362_readings_to_ascii.vhdl \
        lcd_text_feed.vhdl \
        led_pwm_driver.vhdl \
        led_palette_pulser.vhdl \
        \
        pmod_stand_spi_solo_pkg.vhdl \
        pmod_generic_spi_solo.vhdl \
        pmod_acl2_stand_spi_solo.vhdl \
        pmod_cls_stand_spi_solo.vhdl \
        \
        pmod_acl2_custom_driver.vhdl \
        pmod_cls_custom_driver.vhdl \
        \
        uart_tx_feed.vhdl \
        uart_tx_only.vhdl \
        \
        fpga_serial_acl_tester.vhdl \
        ; do

        ghdl_analyze 08 work "${SRC_DIR}/RTL/${filename}"
    done

    for filename in \
        acl_testbench_pkg.vhdl \
        clock_gen.vhdl \
        board_ui.vhdl \
        pmod_acl2.vhdl \
        board_uart.vhdl \
        pmod_cls.vhdl \
        pmod_7sd.vhdl \
        fpga_serial_acl_tester_testbench.vhdl \
        fpga_serial_acl_tester_testharness.vhdl \
        test_default_fpga_regression.vhdl \
        ; do

        ghdl_analyze 08 work "${SRC_DIR}/Testbench/${filename}"
    done
}

function elab_and_run_visual () {
    ghdl_elaborate 08 fpga_serial_acl_tester_tb

    #python3 xilinx_wave_to_ghdl_wave.py fpga_serial_acl_tester_tb_waves.opt \
    #     fpga_serial_acl_tester_tb_100_behav_top.wcfg fpga_serial_acl_tester_tb_100_behav_acl2.wcfg  fpga_serial_acl_tester_tb_100_behav_cls.wcfg

    grep '[<]wvobject' \
        ../Testbench/fpga_serial_acl_tester_tb_100_behav_top.wcfg \
        ../Testbench/fpga_serial_acl_tester_tb_100_behav_cls.wcfg \
        ../Testbench/fpga_serial_acl_tester_tb_100_behav_acl2.wcfg | \
        sed 's!.*fp_name=["]\(.*\)["][>]!\1!' > fpga_serial_acl_tester_tb_waves.opt

    rm -f test.opt

    ghdl_run 08 fpga_serial_acl_tester_tb \
        simulate_fpga_serial_acl_tester.vcd \
        fpga_serial_acl_tester_tb_waves.opt
         
    # --write-wave-opt=test.opt
}

function elab_and_run_batch () {
    ghdl_elaborate 08 test_default_fpga_regression

    rm -f test.opt
    ghdl_generate_optlist 08 test_default_fpga_regression test.vcd test.opt

    ghdl_run_batch 08 test_default_fpga_regression #100ms u_fpga_serial_acl_tester_testbench-acl2-focus.opt u_fpga_serial_acl_tester_testbench-acl2-focus.vcd
}

case "$1" in
    "clean" | "realclean" | "mrproper" )
    clean_work_dir;
    ;;
    "analyze" | "compile" )
    clean_work_dir;
    compile_ossvm;
    compile_ossvm_common;
    # compile_ossvm_axi4_common
    # compile_ossvm_axi4_axi4lite
    # compile_ossvm_axi4_axi4stream
    # compile_ossvm_axi4_axi4
    compile_ossvm_uart;
    compile_work;
    ;;
    "analyze-work" | "compile-work" )
    # clean_work_dir;
    # compile_ossvm;
    # compile_ossvm_common;
    # compile_ossvm_axi4_common
    # compile_ossvm_axi4_axi4lite
    # compile_ossvm_axi4_axi4stream
    # compile_ossvm_axi4_axi4
    # compile_ossvm_uart;
    compile_work;
    ;;
    "simulate" | "run" | "execute" )
    clean_work_dir;
    compile_ossvm;
    compile_ossvm_common;
    # compile_ossvm_axi4_common
    # compile_ossvm_axi4_axi4lite
    # compile_ossvm_axi4_axi4stream
    # compile_ossvm_axi4_axi4
    compile_ossvm_uart;
    compile_work;
    elab_and_run_batch;
    ;;
    *)
    echo "$0 <clean | compile | run >"
    ;;
esac
