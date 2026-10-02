# Navigate to project directory
cd C:/dev/e-yantra/eYRC_26-27_Logic-Quest/Task_1/Task_1A/t1a_fs_pwm

# Clean previous build artifacts and create new work library
if {[file exists work]} { vdel -lib work -all }
vlib work

# Compile source files
vlog -suppress 12110 code/t1a_fs_pwm_bdf.v code/pwm_generator.v code/frequency_scaling.v .test/tb.v
# Start simulation
vsim -voptargs="+acc" work.tb -suppress 12110

# Add waveforms
add wave -r /tb/*

# Run simulation
run -all

# Zoom to fit full timeframe in Wave window
wave zoomfull
