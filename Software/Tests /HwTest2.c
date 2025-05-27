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

// raw status read
static byte read_status(void) {
    return IORD_32DIRECT(I2C_0_BASE, STATUS_REGISTER);
}

// clear status bits (W1C)
static void clear_status_bits(byte bits) {
    IOWR_32DIRECT(I2C_0_BASE, STATUS_REGISTER, bits);
}

// wait for READY or NACK
static byte wait_ready(void) {
    byte status;
    while (1) {
        status = read_status();
        printf("waiting READY or NACK, status=0x%02X\n", status);
        if (status & ACKERROR_BIT) {
            printf("   NACK detected (status=0x%02X)\n", status);
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

// wait for DONE or NACK
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

// write one byte into 'reg'
static void write_byte(byte reg, byte data) {
    printf("\n-- WRITE reg=0x%02X data=0x%02X\n", reg, data);

    // 1) set pointer
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, 0);
    IOWR_32DIRECT(I2C_0_BASE, WRITE_REGISTER, (RTC_ADDRESS<<8)|reg);
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT);
    wait_ready();

    // 2) write data
    IOWR_32DIRECT(I2C_0_BASE, WRITE_REGISTER, (RTC_ADDRESS<<8)|data);
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT|CONTINUE_BIT);
    wait_ready();

    // 3) STOP & done
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT|STOP_BIT);
    wait_done();

    printf("-- WRITE complete reg=0x%02X\n", reg);
}

// read one byte from 'reg'
static byte read_byte(byte reg) {
    byte result;

    printf("\n-- READ reg=0x%02X\n", reg);

    // 1) set pointer
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, 0);
    IOWR_32DIRECT(I2C_0_BASE, WRITE_REGISTER, (RTC_ADDRESS<<8)|reg);
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT);
    wait_ready();

    // STOP pointer
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT|STOP_BIT);
    wait_done();

    // 2) read
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT|RW_BIT);
    wait_done();

    result = IORD_32DIRECT(I2C_0_BASE, READ_REGISTER);
    printf("read data=0x%02X\n", result);
    return result;
}

// —————————————— New: Multi-Byte Burst R/W ——————————————

static void burst_write(byte start_reg, byte *data, int len) {
    printf("\n-- BURST WRITE start=0x%02X len=%d\n", start_reg, len);

    // pointer
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, 0);
    IOWR_32DIRECT(I2C_0_BASE, WRITE_REGISTER, (RTC_ADDRESS<<8)|start_reg);
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT);
    wait_ready();

    // data bytes
    for (int i = 0; i < len; i++) {
        byte ctrl = ENABLE_BIT | (i < len-1 ? CONTINUE_BIT : STOP_BIT);
        IOWR_32DIRECT(I2C_0_BASE, WRITE_REGISTER, (RTC_ADDRESS<<8)|data[i]);
        IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ctrl);
        if (i < len-1) wait_ready();
        else           wait_done();
    }
    printf("-- BURST WRITE complete\n");
}

static void burst_read(byte start_reg, byte *buf, int len) {
    printf("\n-- BURST READ start=0x%02X len=%d\n", start_reg, len);

    // set pointer
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, 0);
    IOWR_32DIRECT(I2C_0_BASE, WRITE_REGISTER, (RTC_ADDRESS<<8)|start_reg);
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT);
    wait_ready();
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT|STOP_BIT);
    wait_done();

    // read bytes
    for (int i = 0; i < len; i++) {
        byte ctrl = ENABLE_BIT | RW_BIT | (i < len-1 ? CONTINUE_BIT : STOP_BIT);
        IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ctrl);
        wait_done();
        buf[i] = IORD_32DIRECT(I2C_0_BASE, READ_REGISTER);
        printf(" read[%d]=0x%02X\n", i, buf[i]);
    }
    printf("-- BURST READ complete\n");
}

// —————————————————————————————————————————————————————————————

void set_rtc_time(byte s, byte m, byte h,
                  byte wd, byte d, byte mo, byte yr) {
    byte bcd;
    bcd = ((s/10)<<4)|(s%10); write_byte(REG_SECONDS, bcd);
    bcd = ((m/10)<<4)|(m%10); write_byte(REG_MINUTES, bcd);
    bcd = ((h/10)<<4)|(h%10); write_byte(REG_HOURS,   bcd);
    bcd = ((wd/10)<<4)|(wd%10); write_byte(REG_WEEKDAY, bcd);
    bcd = ((d/10)<<4)|(d%10); write_byte(REG_DAY,     bcd);
    bcd = ((mo/10)<<4)|(mo%10); write_byte(REG_MONTH,   bcd);
    bcd = ((yr/10)<<4)|(yr%10); write_byte(REG_YEAR,    bcd);
}

void get_rtc_time(byte *s, byte *m, byte *h,
                  byte *wd, byte *d, byte *mo, byte *yr) {
    byte raw;
    raw = read_byte(REG_SECONDS); *s = ((raw>>4)*10)+(raw&0x0F);
    raw = read_byte(REG_MINUTES); *m = ((raw>>4)*10)+(raw&0x0F);
    raw = read_byte(REG_HOURS);   *h = ((raw>>4)*10)+(raw&0x0F);
    raw = read_byte(REG_WEEKDAY); *wd = ((raw>>4)*10)+(raw&0x0F);
    raw = read_byte(REG_DAY);     *d = ((raw>>4)*10)+(raw&0x0F);
    raw = read_byte(REG_MONTH);   *mo = ((raw>>4)*10)+(raw&0x0F);
    raw = read_byte(REG_YEAR);    *yr = ((raw>>4)*10)+(raw&0x0F);
}

float get_rtc_temp(void) {
    byte hi = read_byte(REG_TEMP_HIGH);
    byte lo = read_byte(REG_TEMP_LOW);
    int ti = (hi & 0x80) ? hi - 256 : hi;
    float temp = ti + (((lo>>6)&3)*0.25f);
    printf("temp raw hi=0x%02X lo=0x%02X => %.2f\n", hi, lo, temp);
    return temp;
}

int main(void) {
    byte sec, min, hr, wd, d, mo, yr;
    float tmp;
    printf("=== RTC Demo Start ===\n");

    // — initial set/get/temp demo —
    set_rtc_time(30,46,7, 3,14,2,25);
    get_rtc_time(&sec,&min,&hr,&wd,&d,&mo,&yr);
    tmp = get_rtc_temp();
    printf("\nFinal: %02d:%02d:%02d  %02d/%02d/20%02d   Temp=%.2f°C\n",
           hr,min,sec, d,mo,yr, tmp);

    // — 1) MultiByte Burst test —
    byte out3[3] = {
      ((30/10)<<4)|(30%10),
      ((46/10)<<4)|(46%10),
      (( 7/10)<<4)|( 7%10)
    }, in3[3];
    burst_write(REG_SECONDS, out3, 3);
    burst_read (REG_SECONDS, in3 , 3);
    printf("Burst decoded: sec=%02d min=%02d hr=%02d\n",
           ((in3[0]>>4)*10)+(in3[0]&0x0F),
           ((in3[1]>>4)*10)+(in3[1]&0x0F),
           ((in3[2]>>4)*10)+(in3[2]&0x0F));

    // — 2) EdgeCase BCD limits —
    write_byte(REG_SECONDS, 0x00);
    write_byte(REG_MINUTES, 0x59);
    sec = read_byte(REG_SECONDS);
    min = read_byte(REG_MINUTES);
    printf("Edgecase read: seconds=0x%02X minutes=0x%02X\n", sec, min);

    // — 3) Invalid BCD injection —
    write_byte(REG_SECONDS, 0x6A);
    sec = read_byte(REG_SECONDS);
    printf("Invalid BCD read back seconds=0x%02X\n", sec);

    return 0;
}
