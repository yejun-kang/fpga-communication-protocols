# fpga-communication-protocols

A structured collection of SystemVerilog digital logic implementations, serial communication controllers, and bus interfaces, complete with self-checking testbenches, simulation waveforms, and hardware verification on the Digilent Basys 3 FPGA board.

## Table of Contents

| Module / Protocol | Description | Directory | Verification / Demo |
| :--- | :--- | :---: | :---: |
| **ALU Hardware Demo** | 8-operation Arithmetic Logic Unit implemented on Basys 3 FPGA | [alu](./alu/) | [Basys 3 Demo Photo](./alu/docs/alu_basys.png) |
| **UART** | Full-duplex asynchronous serial controller with XDC constraints | [uart](./uart/) | [Waveform](./uart/docs/uart.png) \| [Terminal Demo](./uart/docs/uart_powershell.png) | [Basys 3 Demo Photo](./uart/docs/uart_basys.png) |
| **SPI Master** | Parameterized Mode 0 (CPOL=0, CPHA=0) controller | [spi](./spi/) | [Waveform](./spi/docs/spi_master.png) |
| **I2C Master** | Single-master bus controller with ACK/NACK handling | [i2c](./i2c/) | [Waveform](./i2c/docs/i2c_master.png) |
| **AXI4-Lite** | 32-bit memory-mapped slave register interface | [axi_lite](./axi_lite/) | [Waveform](./axi_lite/docs/axi_lite_slave.png) |

---

## Detailed Directory Links

* [**alu**](./alu/)
  * [ALU Documentation (`README.md`)](./alu/README.md)
  * [Basys 3 Board Demo Image](./alu/docs/alu_basys.png)
* [**uart**](./uart/)
  * [Transmitter (`uart_tx.sv`)](./uart/uart_tx.sv)
  * [Receiver (`uart_rx.sv`)](./uart/uart_rx.sv)
  * [Top Level (`uart_top.sv`)](./uart/uart_top.sv)
  * [Basys 3 Constraints (`basys3_uart.xdc`)](./uart/basys3_uart.xdc)
  * [Basys 3 Board Demo Image](./uart/docs/uart_basys.png)
* [**spi**](./spi/)
  * [SPI Master Core (`spi_master.sv`)](./spi/spi_master.sv)
* [**i2c**](./i2c/)
  * [I2C Master Core (`i2c_master.sv`)](./i2c/i2c_master.sv)
* [**axi_lite**](./axi_lite/)
  * [AXI4-Lite Slave (`axi_lite_slave.sv`)](./axi_lite/axi_lite_slave.sv)
