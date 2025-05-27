#include "rtc_driver.h"

// Read the raw status register
static byte read_status(void) {
    return IORD_32DIRECT(I2C_0_BASE, STATUS_REGISTER);
}

// Clear specified status bits (write-1-to-clear)
static void clear_status_bits(byte bits) {
    IOWR_32DIRECT(I2C_0_BASE, STATUS_REGISTER, bits);
}

// Wait until READY or ACK error, then clear error if any
static void wait_ready(void) {
    byte status;
    do {
        status = read_status();
    } while (!(status & (READY_BIT | ACKERROR_BIT)));
    if (status & ACKERROR_BIT) {
        clear_status_bits(ACKERROR_BIT);
    }
}

// Wait until DONE or ACK error, then clear error if any
static void wait_done(void) {
    byte status;
    do {
        status = read_status();
    } while (!(status & (DONE_BIT | ACKERROR_BIT)));
    if (status & ACKERROR_BIT) {
        clear_status_bits(ACKERROR_BIT);
    }
}

// Write a single byte to the given register
static void write_byte(byte reg, byte data) {
    // Point to register
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, 0);
    IOWR_32DIRECT(I2C_0_BASE, WRITE_REGISTER, (RTC_ADDRESS << 8) | reg);
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT);
    wait_ready();

    // Write data and issue STOP
    IOWR_32DIRECT(I2C_0_BASE, WRITE_REGISTER, (RTC_ADDRESS << 8) | data);
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT | STOP_BIT);
    wait_done();
}

// Read a single byte from the given register
static byte read_byte(byte reg) {
    byte result;

    // Point to register
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, 0);
    IOWR_32DIRECT(I2C_0_BASE, WRITE_REGISTER, (RTC_ADDRESS << 8) | reg);
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT);
    wait_ready();

    // Issue STOP for pointer write
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT | STOP_BIT);
    wait_done();

    // Read data byte
    IOWR_32DIRECT(I2C_0_BASE, CONTROL_REGISTER, ENABLE_BIT | RW_BIT);
    wait_done();
    result = IORD_32DIRECT(I2C_0_BASE, READ_REGISTER);
    return result;
}

void set_rtc_time(byte second, byte minute, byte hour,
                  byte week_day, byte day, byte month, byte year) {
    byte bcd;
    bcd = ((second / 10) << 4) | (second % 10);
    write_byte(REG_SECONDS, bcd);
    bcd = ((minute / 10) << 4) | (minute % 10);
    write_byte(REG_MINUTES, bcd);
    bcd = ((hour   / 10) << 4) | (hour   % 10);
    write_byte(REG_HOURS,   bcd);
    bcd = ((week_day/ 10) << 4) | (week_day% 10);
    write_byte(REG_WEEKDAY, bcd);
    bcd = ((day    / 10) << 4) | (day    % 10);
    write_byte(REG_DAY,     bcd);
    bcd = ((month  / 10) << 4) | (month  % 10);
    write_byte(REG_MONTH,   bcd);
    bcd = ((year   / 10) << 4) | (year   % 10);
    write_byte(REG_YEAR,    bcd);
}

void get_rtc_time(byte *second, byte *minute, byte *hour,
                  byte *week_day, byte *day, byte *month, byte *year) {
    byte raw;
    raw = read_byte(REG_SECONDS);
    *second   = ((raw >> 4) * 10) + (raw & 0x0F);
    raw = read_byte(REG_MINUTES);
    *minute   = ((raw >> 4) * 10) + (raw & 0x0F);
    raw = read_byte(REG_HOURS);
    *hour     = ((raw >> 4) * 10) + (raw & 0x0F);
    raw = read_byte(REG_WEEKDAY);
    *week_day = ((raw >> 4) * 10) + (raw & 0x0F);
    raw = read_byte(REG_DAY);
    *day      = ((raw >> 4) * 10) + (raw & 0x0F);
    raw = read_byte(REG_MONTH);
    *month    = ((raw >> 4) * 10) + (raw & 0x0F);
    raw = read_byte(REG_YEAR);
    *year     = ((raw >> 4) * 10) + (raw & 0x0F);
}

float get_rtc_temp(void) {
    byte hi = read_byte(REG_TEMP_HIGH);
    byte lo = read_byte(REG_TEMP_LOW);
    int ti = (hi & 0x80) ? hi - 256 : hi;
    return ti + (((lo >> 6) & 0x03) * 0.25f);
}

