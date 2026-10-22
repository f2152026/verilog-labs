FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive

# iverilog + gtkwave: simulation and waveforms
# yosys + graphviz:   synthesis and circuit drawings (scripts/synth.sh, Lab 3 onwards)
RUN apt-get update && apt-get install -y     iverilog     gtkwave     yosys     graphviz     unzip  && curl -fsSL https://raw.githubusercontent.com/phillbush/vcd2svg/master/vcd2svg     -o /usr/local/bin/vcd2svg  && chmod +x /usr/local/bin/vcd2svg  && apt-get clean && rm -rf /var/lib/apt/lists/*
