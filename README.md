# AXI4-Lite to SPI Bridge

A synthesizable **SystemVerilog-based AXI4-Lite to SPI Bridge** that allows an AXI4-Lite master to communicate with SPI peripherals through a memory-mapped interface.

The design converts AXI4-Lite read/write transactions into SPI transfers while providing FIFO-based buffering between the AXI and SPI interfaces.

---

## Overview

The bridge consists of:

* AXI4-Lite Slave Interface
* Control and Status Registers
* Transmit FIFO
* Receive FIFO
* SPI Controller
* Programmable SPI Clock Divider
* Chip-Select Control

The design is intended for **FPGA and ASIC-based SoC integration**.

---

## Key Features

✔ AXI4-Lite Slave Interface
✔ SPI Master Interface
✔ Full-Duplex SPI Communication
✔ Memory-Mapped Control
✔ TX and RX FIFOs
✔ Programmable SPI Clock
✔ Hardware Chip-Select Control
✔ Configurable Baud-Rate Divider
✔ Synthesizable SystemVerilog RTL
✔ Simulation-Based Verification

---

## Architecture

```text
             AXI4-Lite Master
                    |
                    v
            +---------------+
            | AXI4-Lite     |
            | Slave         |
            +-------+-------+
                    |
             Control Registers
                    |
          +---------+---------+
          |                   |
          v                   v
       TX FIFO             RX FIFO
          |                   ^
          v                   |
       +-----------------------+
       |    SPI Controller     |
       +-----------+-----------+
                   |
              SPI Interface
             SCLK MOSI MISO CS
```

The AXI master writes transmit data into the **TX FIFO**. The SPI controller retrieves the data and performs the SPI transfer.

Received SPI data is stored in the **RX FIFO**, where it can subsequently be read through the AXI4-Lite interface.

---

## AXI4-Lite Interface

The bridge operates as an **AXI4-Lite slave** and supports:

* AXI Write Address Channel
* AXI Write Data Channel
* AXI Write Response Channel
* AXI Read Address Channel
* AXI Read Data Channel

The SPI controller is accessed through memory-mapped registers.

---

## Register Map

| Address | Register | Description       |
| ------- | -------- | ----------------- |
| `0x00`  | CONTROL  | SPI control       |
| `0x04`  | STATUS   | SPI/FIFO status   |
| `0x08`  | TX_DATA  | Transmit data     |
| `0x0C`  | RX_DATA  | Receive data      |
| `0x10`  | SPI_CTRL | SPI configuration |
| `0x14`  | BAUD_DIV | SPI clock divider |

> Update the register addresses above to match the final RTL implementation.

---

## SPI Controller

The SPI controller handles:

* SPI clock generation
* MOSI data shifting
* MISO data sampling
* Chip-select control
* Transfer completion

The SPI clock is generated from the system clock using a programmable divider, allowing different SPI clock frequencies to be selected.

---

## Data Transfer

A typical transfer follows:

```text
AXI Write
    |
    v
TX FIFO
    |
    v
SPI Controller
    |
    +----> MOSI
    +----> SCLK
    +----> CS
    |
    <---- MISO
    |
    v
RX FIFO
    |
    v
AXI Read
```

---

## Verification

The RTL is verified using simulation-based testbenches covering:

* AXI4-Lite read/write transactions
* Register access
* TX/RX FIFO operation
* SPI data transmission
* SPI data reception
* SPI clock generation
* Chip-select behavior
* End-to-end AXI-to-SPI communication

---

## Applications

* FPGA-based SoCs
* ASIC SoCs
* RISC-V systems
* Embedded processors
* SPI sensors
* ADC/DAC interfaces
* SPI Flash and EEPROM
* Custom AXI peripherals

---

## Getting Started

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
cd YOUR_REPOSITORY
```

Compile the SystemVerilog RTL and testbench using a simulator such as:

* ModelSim / QuestaSim
* Vivado Simulator
* Xcelium
* VCS
* Verilator

Run the testbench to verify AXI4-Lite to SPI communication.

---

## Author

**Bishal Sarma**
Department of Electronics and Communication Engineering
National Institute of Technology Silchar

GitHub: https://github.com/svsBishal

---

## License

This project is released under the **MIT License**.
