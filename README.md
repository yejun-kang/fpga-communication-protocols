# Week 3: Serial Communication Protocols & AXI4-Lite Interface

This repository contains SystemVerilog implementations and testbenches for standard digital communication interfaces and bus protocols.

## Modules Included

* **UART Controller**: Fully synchronous UART TX/RX core targeted for Basys 3 FPGA deployment.
* **SPI Master**: Configurable Serial Peripheral Interface controller with parameterized clock frequency and word length.
* **I2C Master**: Inter-Integrated Circuit master controller supporting standard start/stop conditions and byte transfers with ACK/NACK handling.
* **AXI4-Lite Slave**: Memory-mapped register interface implementing standard AXI4-Lite read/write channel handshakes.

## Repository Organization

* `uart/`: UART transmitter/receiver modules, constraints, and testbenches.
* `spi/`: SPI Master implementation and verification.
* `i2c/`: I2C Master module and functional testbench.
* `axi_lite/`: AXI4-Lite register slave module and simulation testbench.
