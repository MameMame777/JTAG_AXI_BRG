# dsim compilation and simulation script for JTAG-AXI Bridge
# Author: FPGA Engineer
# Date: 2025-07-23
# Description: Compilation and simulation script for dsim simulator

# Create simulation directory
if [ ! -d "sim" ]; then
    mkdir sim
fi

cd sim

# Clean previous simulation
rm -rf dsim_work
rm -rf *.log
rm -rf *.wlf

echo "Starting dsim compilation and simulation..."
echo "=========================================="

# Compile SystemVerilog files
echo "Compiling RTL files..."

dsim \
    -genimage image \
    -work work \
    +incdir+../rtl \
    +incdir+../tb \
    ../rtl/Jtag_Axi_Bridge.sv \
    ../rtl/Simple_Led_Register.sv \
    ../rtl/Jtag_Axi_Top.sv \
    ../tb/tb_simple_jtag_led.sv \
    -top tb_simple_jtag_led \
    -timescale 1ns/1ps \
    -sv \
    -access +rwc \
    +define+SIMULATION \
    -f compile.log

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed!"
    exit 1
fi

echo "Compilation successful!"

# Run simulation
echo "Running simulation..."

dsim \
    -image image \
    -waves waves.mxd \
    -sv_seed random \
    +access+r \
    tb_simple_jtag_led \
    -f sim.log

if [ $? -ne 0 ]; then
    echo "ERROR: Simulation failed!"
    exit 1
fi

echo "Simulation completed!"
echo "Check sim.log for simulation results"
echo "Use 'simvision waves.mxd' to view waveforms"

cd ..
