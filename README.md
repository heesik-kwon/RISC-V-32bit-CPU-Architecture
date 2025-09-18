# 📈 RV32I 명령어 Simulation Result

**Single Cycle Simulation(위)** /  **Multi Cycle Simulation(아래)** 입니다. 연산 결과가 동일하게 나온 것을 확인할 수 있습니다.

## 1️⃣ R-Type 명령어 Simulation

```verilog
rom[0] = 32'b0000000_00001_00010_000_00100_0110011; // ADD
rom[1] = 32'b0100000_00001_00010_000_00101_0110011; // SUB
rom[2] = 32'b0000000_00001_00010_001_00110_0110011; // SLL
rom[3] = 32'b0000000_00001_00010_101_00111_0110011; // SRL
rom[4] = 32'b0100000_00001_00010_101_01000_0110011; // SRA
rom[5] = 32'b0000000_00001_00010_010_01001_0110011; // SLT
rom[6] = 32'b0000000_00001_00010_011_01010_0110011; // SLTU
rom[7] = 32'b0000000_00001_00010_100_01011_0110011; // XOR
rom[8] = 32'b0000000_00001_00010_110_01100_0110011; // OR
rom[9] = 32'b0000000_00001_00010_111_01101_0110011; // AND
```
<img width="1609" height="559" alt="image" src="https://github.com/user-attachments/assets/ff793a2a-8f0b-4d70-9526-1656c4a2c54b" />

## 2️⃣ I-Type 명령어 Simulation

```verilog
rom[10] = 32'b111111111100_00010_000_10011_0010011; // ADDI
rom[11] = 32'b111111111100_00010_010_10100_0010011; // SLTI
rom[12] = 32'b111111111100_00010_011_10101_0010011; // SLTIU
rom[13] = 32'b0000000100_00010_100_10110_0010011;   // XORI
rom[14] = 32'b0000000100_00010_110_10111_0010011;   // ORI
rom[15] = 32'b0000000100_00010_111_11000_0010011;   // ANDI
rom[16] = 32'b000000000001_00010_001_11001_0010011; // SLLI
rom[17] = 32'b000000000001_00100_101_11010_0010011; // SRLI
rom[18] = 32'b010000000001_00100_101_11011_0010011; // SRAI
```
<img width="2029" height="782" alt="image" src="https://github.com/user-attachments/assets/7555d9bf-e7c0-4ca1-a231-2fe554df99f4" />

## 3️⃣ S-Type 명령어 Simulation
```verilog
rom[19] = 32'b0000000_10011_00000_010_10000_0100011; // SW
rom[20] = 32'b0000000_10011_00000_000_10001_0100011; // SB
rom[21] = 32'b0000000_10011_00000_001_10010_0100011; // SH
```
<img width="2070" height="159" alt="image" src="https://github.com/user-attachments/assets/2832a53e-f881-4f71-8b3d-8b3bc509b69e" />

## 4️⃣ L-Type 명령어 Simulation
```verilog
rom[22] = 32'b000000010000_00000_000_01110_0000011; // LB
rom[23] = 32'b000000010000_00000_001_01111_0000011; // LH
rom[24] = 32'b000000010000_00000_010_10000_0000011; // LW
rom[25] = 32'b000000010000_00000_100_10001_0000011; // LBU
rom[26] = 32'b000000010000_00000_101_10010_0000011; // LHU
```
<img width="2140" height="456" alt="image" src="https://github.com/user-attachments/assets/cbbc4b14-eb16-4f5c-903f-a294849c8604" />

## 5️⃣ U-Type 명령어 Simulation
```verilog
rom[27] = 32'b00000000000000000001_11100_0110111; // LUI
rom[28] = 32'b00000000000000000001_11101_0010111; // AUIPC
```
<img width="2118" height="408" alt="image" src="https://github.com/user-attachments/assets/452cd005-b661-4abd-a4e5-beca1479407c" />

## 6️⃣ J-Type 명령어 Simulation
```verilog
rom[29] = 32'b0000000010_0_00000000_11110_1101111; // JAL
rom[30] = 32'b000010001010_00100_000_11111_1100111; // JALR
```
<img width="2147" height="362" alt="image" src="https://github.com/user-attachments/assets/423d435b-6463-4f5e-892f-8808a64ada01" />

## 7️⃣ B-Type 명령어 Simulation
```verilog
rom[0] = 32'b0_000000_00001_00001_000_0_1000_0_1100011; // BEQ
rom[1] = 32'b0_000000_00001_00010_001_0_1000_0_1100011; // BNE
rom[2] = 32'b0_000000_00001_00010_100_0_1000_0_1100011; // BLT
rom[3] = 32'b0_000000_00001_00010_101_0_1000_0_1100011; // BGE
rom[4] = 32'b0_000000_00001_00010_110_0_1000_0_1100011; // BLTU
rom[5] = 32'b0_000000_00011_00001_111_0_1000_0_1100011; // BGEU
```
<img width="2136" height="205" alt="image" src="https://github.com/user-attachments/assets/6702385e-3a8b-4219-953a-e039a7bde3a0" />

---

# 📑 RISC-V+AMBA BUS Testbench Result

## 1️⃣ Test Example 1

- UCR Write, Trigger 발생(예상 Distance: 151)
<img width="1128" height="147" alt="image" src="https://github.com/user-attachments/assets/00028ad1-8f60-41a2-8f99-8132abbc156f" />

- UDR Read, Distance match(실제 Distance: 151)
<img width="1065" height="146" alt="image" src="https://github.com/user-attachments/assets/a1d74f84-c150-4eb6-8183-5ea863fecf91" />

## 2️⃣ Test Example 2

- UCR Write, Trigger 발생(예상 Timeout: 0)
<img width="1408" height="194" alt="image" src="https://github.com/user-attachments/assets/aa7bb57b-52dc-440b-a626-a7f0252f4328" />

- USR Read, Timeout match(실제 Timeout: 0)
<img width="1412" height="191" alt="image" src="https://github.com/user-attachments/assets/5eec9f96-7e30-4cd6-8007-211572325655" />

## 3️⃣ Verification Report
랜덤 테스트 결과 (총 10,000건 수행)

✅ Valid Access : 8,375건  
- **UCR write test** : 1,533건  
- **USR/UDR read test** : 7,442건

❌ Invalid Access : 1,025건  
- UCR 읽기, USR/UDR 쓰기 모두 정상적으로 무시됩니다.

모든 시나리오에서 **DUT 정상 동작**

<img width="400" alt="image" src="https://github.com/user-attachments/assets/f5e6d7e3-b906-4dc3-b60f-99609f7e6cdd" />

---

# 💻 ComPortMaster Test
보드에서 전송한 데이터가 ComportMaster 하단에 출력되는 것을 알 수 있습니다.

<img width="453" height="325" alt="image" src="https://github.com/user-attachments/assets/138b32c2-2fa4-46a6-98cc-5db4d35af57c" />

