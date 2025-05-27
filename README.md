# I2C Master Controller – VHDL Implementation


This repository contains a synthesizable I2C Master subsystem implemented in VHDL, developed as part of an advanced digital design project. The system includes:

- An I2C Master controller conforming to the I²C protocol
- A register bank implemented via the Avalon-MM interface using the SBI protocol
- Top-level integration ("glue logic") for SoC compatibility
- System-level verification using UVVM
- Module-level testbenches for individual units
- A C driver, application-level software, and test cases for host-side integration

All modules are synthesizable and have been verified in simulation. Hardware integration has not yet been finalized. For open issues and integration constraints, refer to the conclusion of the project report.

The repository also includes complete documentation, report, timing diagrams, and a functional datasheet for the subsystem. This project was awarded the highest academic grade (A) in ELE113 – HW & SW systemdesign.

**Author:** Hareth  
**Program:** Dual BEng in Electrical Engineering (Automation & Electronics)  
**Institution:** Western Norway University of Applied Sciences  
**Course:** ELE113 – HW & SW systemdesign   
