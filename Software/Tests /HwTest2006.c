
#include <system.h>
#include <io.h>
#include <stdio.h>

typedef unsigned char byte;

// register addresses
#define I2C_0_BASE        0x81000
#define CONTROL_REGISTER  0x00  // bit3=continue bit2=rw bit1=stop bit0=enable
#define WRITE_REGISTER    0x04  // bits14-8=slave bits7-0=data
#define STATUS_REGISTER   0x08  // bit3=ready bit2=ackerror bit1=busy bit0=done
#define READ_REGISTER     0x0C  // bits7-0=dataout

// control bits
#define ENABLE_BIT        0x01
#define STOP_BIT          0x02
#define RW_BIT            0x04
#define CONTINUE_BIT      0x08

// status bits
#define READY_BIT         0x08
#define ACKERROR_BIT      0x04
#define BUSY_BIT          0x02
#define DONE_BIT          0x01

// DS3231 address & registers
#define RTC_ADDRESS       0x68
#define REG_SECONDS       0x00
#define REG_MINUTES       0x01
#define REG_HOURS         0x02
#define REG_WEEKDAY       0x03
#define REG_DAY           0x04
#define REG_MONTH         0x05
#define REG_YEAR          0x06
#define REG_TEMP_HIGH     0x11
#define REG_TEMP_LOW      0x12

// read raw status
static byte read_status(void) {
    return IORD_32DIRECT(I2C_0_BASE, STATUS_REGISTER);
}

// clear only the given status bits (write-1-to-clear)
static void clear_status_bits(byte bits) {
    IOWR_32DIRECT(I2C_0_BASE, STATUS_REGISTER, bits);
}

// wait until READY or ACKERROR; return last status
static byte wait_ready(void) {
    byte status;
    while (1) {
        status = read_status();
        printf("waiting READY or NACK, status=0x%02X\n", status);
        if (status & ACKERROR_BIT) {
            printf("   NACK detected (status=0x%02X)\n", status);
            // clear NACK so future ops can proceed
            clear_status_bits(ACKERROR_BIT);
            break;
        }
        if (status & READY_BIT) {
            printf("   READY asserted (status=0x%02X)\n", status);
            break;
        }
    }
    return status;
}

// wait until DONE or ACKERROR; return last status
static byte wait_done(void) {
    byte status;
    while (1) {
        status = read_status();
        printf("waiting DONE or NACK, status=0x%02X\n", status);
        if (status & ACKERROR_BIT) {
            printf("   NACK detected (status=0x%02X)\n", status);
            clear_status_bits(ACKERROR_BIT);
            break;
        }
        if (status & DONE_BIT) {
            printf("   DONE asserted (status=0x%02X)\n", status);
            break;
        }
    }
    return status;
}

// write one byte into register 'reg'
static void write_byte(byte reg, byte data) {
    printf("\n-- WRITE reg=0x%02X data=0x%02X\n", reg, data);

    // 1) set pointer address
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, 0);
    IOWR_32DIRECT(I2C_0_BASE, WRITE_REGISTER, (RTC_ADDRESS << 8) | reg);
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT);
    wait_ready();

    // 2) write data, keep bus asserted (CONTINUE)
    IOWR_32DIRECT(I2C_0_BASE, WRITE_REGISTER, (RTC_ADDRESS << 8) | data);
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT | CONTINUE_BIT);
    wait_ready();

    // 3) issue STOP and wait for DONE
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT | STOP_BIT);
    wait_done();

    printf("-- WRITE complete reg=0x%02X\n", reg);
}

// read one byte from register 'reg'
static byte read_byte(byte reg) {
    byte result;

    printf("\n-- READ reg=0x%02X\n", reg);

    // 1) set pointer
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, 0);
    IOWR_32DIRECT(I2C_0_BASE, WRITE_REGISTER, (RTC_ADDRESS << 8) | reg);
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT);
    wait_ready();
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT | STOP_BIT);
    wait_done();

    // 2) perform read
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT | RW_BIT);
    wait_done();

    result = IORD_32DIRECT(I2C_0_BASE, READ_REGISTER);
    printf("read data=0x%02X\n", result);
    return result;
}


void set_rtc_time(byte s, byte m, byte h,
                  byte wd, byte d, byte mo, byte yr) {
    byte bcd;
    bcd = ((s / 10) << 4) | (s % 10);
    write_byte(REG_SECONDS, bcd);
    bcd = ((m / 10) << 4) | (m % 10);
    write_byte(REG_MINUTES, bcd);
    bcd = ((h / 10) << 4) | (h % 10);
    write_byte(REG_HOURS, bcd);
    bcd = ((wd / 10) << 4) | (wd % 10);
    write_byte(REG_WEEKDAY, bcd);
    bcd = ((d / 10) << 4) | (d % 10);
    write_byte(REG_DAY, bcd);
    bcd = ((mo / 10) << 4) | (mo % 10);
    write_byte(REG_MONTH, bcd);
    bcd = ((yr / 10) << 4) | (yr % 10);
    write_byte(REG_YEAR, bcd);
}

void get_rtc_time(byte *s, byte *m, byte *h,
                  byte *wd, byte *d, byte *mo, byte *yr) {
    byte raw;
    raw = read_byte(REG_SECONDS);
    *s = ((raw >> 4) * 10) + (raw & 0x0F);
    raw = read_byte(REG_MINUTES);
    *m = ((raw >> 4) * 10) + (raw & 0x0F);
    raw = read_byte(REG_HOURS);
    *h = ((raw >> 4) * 10) + (raw & 0x0F);
    raw = read_byte(REG_WEEKDAY);
    *wd = ((raw >> 4) * 10) + (raw & 0x0F);
    raw = read_byte(REG_DAY);
    *d = ((raw >> 4) * 10) + (raw & 0x0F);
    raw = read_byte(REG_MONTH);
    *mo = ((raw >> 4) * 10) + (raw & 0x0F);
    raw = read_byte(REG_YEAR);
    *yr = ((raw >> 4) * 10) + (raw & 0x0F);
}

float get_rtc_temp(void) {
    byte hi = read_byte(REG_TEMP_HIGH);
    byte lo = read_byte(REG_TEMP_LOW);
    int ti = (hi & 0x80) ? hi - 256 : hi;
    float temp = ti + (((lo >> 6) & 3) * 0.25f);
    printf("temp raw hi=0x%02X lo=0x%02X => %.2f\n", hi, lo, temp);
    return temp;
}


int main(void) {
    byte sec, min, hr, wd, d, mo, yr;
    float tmp;

    printf("=== RTC Demo Start ===\n");
    set_rtc_time(30, 46, 7, 3, 14, 2, 25);
    get_rtc_time(&sec, &min, &hr, &wd, &d, &mo, &yr);
    tmp = get_rtc_temp();
    printf("\nFinal: %02d:%02d:%02d  %02d/%02d/20%02d   Temp=%.2f°C\n",
           hr, min, sec, d, mo, yr, tmp);
    return 0;
}
