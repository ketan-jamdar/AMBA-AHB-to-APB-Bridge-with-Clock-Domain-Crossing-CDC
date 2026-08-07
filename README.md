# Design and UVM-Based Verification of AMBA AHB-to-APB Bridge with Clock Domain Crossing (CDC)

A high-performance **AMBA AHB-to-APB Bridge** designed in **SystemVerilog** with support for **Clock Domain Crossing (CDC)** using an **Asynchronous FIFO**, and verified using a **Universal Verification Methodology (UVM)** based testbench.

The bridge interfaces a high-speed **AMBA AHB bus** with low-speed **AMBA APB peripherals**, enabling reliable communication between different clock domains while ensuring protocol compliance and data integrity.

---

## 📌 Project Overview

Modern SoCs frequently connect high-performance processors operating on the **AHB bus** with slower peripheral devices communicating over the **APB bus**. Since these buses often operate under different clock domains, reliable Clock Domain Crossing (CDC) becomes an essential design challenge.

This project implements an **AHB-to-APB Bridge** capable of handling asynchronous clock domains by integrating an **Asynchronous FIFO** between the AHB and APB interfaces. The design ensures safe transfer of address, data, and control information while preventing metastability.

To validate the functionality and protocol compliance, the complete RTL is verified using a **UVM-based verification environment**, covering write transactions, read transactions, wait-state handling, FIFO operations, and response synchronization across clock domains.

---

## ✨ Key Features

- AMBA AHB Slave Interface
- AMBA APB Master Interface
- Independent HCLK and PCLK Domains
- Clock Domain Crossing (CDC) Support
- Asynchronous FIFO using Gray Code Pointers
- Dual-Clock FIFO Architecture
- APB Controller Finite State Machine (FSM)
- Response Synchronizer for PCLK → HCLK Communication
- Parameterized RTL Design
- Support for Read and Write Transactions
- APB Wait-State Handling using PREADY
- PSLVERR Error Propagation
- Modular and Scalable Architecture
- UVM-Based Functional Verification
- Functional Coverage Collection
- Reusable Verification Components

---

# 🏗️ Project Architecture

The bridge is divided into two independent clock domains:

### HCLK Domain
- Receives transactions from the AHB Master.
- Captures address, data, and control signals.
- Pushes transactions into the Asynchronous FIFO.
- Receives synchronized read responses from the Response Synchronizer.
- Generates HRDATA, HRESP, and HREADYOUT.

### PCLK Domain
- Reads transactions from the FIFO.
- Generates APB control signals.
- Performs APB read/write operations.
- Captures PRDATA and PSLVERR.
- Sends responses back through the Response Synchronizer.

---

<img width="1536" height="1024" alt="Image" src="https://github.com/user-attachments/assets/28dbfeb5-fe9c-4b96-aaef-491fe65ac562" />

---

# 🔄 Complete Transaction Flow

The bridge supports both **AHB Write** and **AHB Read** transactions.

### Write Transaction

1. AHB Master initiates a write transaction.
2. AHB Interface captures the request.
3. Transaction is stored inside the Asynchronous FIFO.
4. APB Controller reads the FIFO entry.
5. APB write signals are generated.
6. Peripheral completes the write operation.

### Read Transaction

1. AHB Master initiates a read transaction.
2. Transaction is stored inside the FIFO.
3. APB Controller performs APB read.
4. Read data and response are captured.
5. Response Synchronizer safely transfers them to the HCLK domain.
6. AHB Interface returns HRDATA and HRESP to the master.

<img width="1536" height="1024" alt="Image" src="https://github.com/user-attachments/assets/ae6023b4-52df-4a41-be48-48c8b242ae0f" />

---

# ⚙️ APB Controller FSM

The APB Controller controls every APB transaction using a Finite State Machine.

### FSM States

| State | Description |
|--------|-------------|
| IDLE | Waits for a valid FIFO transaction |
| SETUP | Latches transaction and drives APB setup signals |
| ENABLE | Performs APB transfer and waits for PREADY |
| WAIT_RESP | Waits for response synchronization during read operations |
| DONE | Completes current transfer and checks for the next transaction |

The FSM supports:

- APB Setup Phase
- APB Enable Phase
- Wait-State Handling
- Read Data Capture
- Error Capture
- Continuous FIFO Processing

<img width="1536" height="1024" alt="Image" src="https://github.com/user-attachments/assets/261b753e-a46d-4ad1-8b3a-0a993200c40c" />

---

# 📦 Asynchronous FIFO (CDC Buffer)

The Asynchronous FIFO safely transfers transactions between the **HCLK** and **PCLK** domains.

### Features

- Dual Clock FIFO
- Independent Read/Write Clocks
- Gray Code Pointer Synchronization
- Binary Pointer Management
- Full Detection Logic
- Empty Detection Logic
- Two-Flip-Flop Synchronizers
- Safe Clock Domain Crossing

The FIFO eliminates metastability by synchronizing Gray-coded pointers between clock domains.

<img width="1672" height="941" alt="Image" src="https://github.com/user-attachments/assets/4de8d002-d972-4993-b555-289444cbbe0c" />

---

# 🔄 Response Synchronizer

The Response Synchronizer safely transfers APB responses back to the AHB clock domain.

### Responsibilities

- Captures Read Data
- Captures PSLVERR
- Generates Read Valid Pulse
- Toggle-Based Handshake
- Two-Flip-Flop Synchronizers
- Busy Signal Generation
- Safe Multi-bit Data Transfer

The handshake mechanism guarantees that every APB read response is transferred exactly once without data corruption.

<img width="1536" height="1024" alt="Image" src="https://github.com/user-attachments/assets/6bd4493c-183e-4ca2-b6ad-063fe8992175" />
