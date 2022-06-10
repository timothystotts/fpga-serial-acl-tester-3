/******************************************************************************/
/*                                                                            */
/* PmodACL2custom.h -- Driver definitions for the Pmod ACL2                         */
/*                                                                            */
/******************************************************************************/
/* Author: Mikel Skreen                                                       */
/* Copyright 2016, Digilent Inc.                                              */
/******************************************************************************/
/* File Description:                                                          */
/*                                                                            */
/* This file contains a basic library in order to interface with the PmodACL2 */
/*                                                                            */
/******************************************************************************/
/* Revision History:                                                          */
/*                                                                            */
/*    04/19/2016(MikelS):   Created                                           */
/*    08/24/2017(artvvb):   Validated for Vivado 2015.4                       */
/*    02/03/2018(atangzwj): Validated for Vivado 2017.4                       */
/*    11/04/2019(TimS):     Modified execution parameters of ADXL362          */
/*                                                                            */
/******************************************************************************/


#ifndef SRC_PMODACL2CUSTOM_H_
#define SRC_PMODACL2CUSTOM_H_

/****************** Include Files ********************/

#include "xil_types.h"
#include "xspi.h"
#include "xspi_l.h"
#include "xstatus.h"

/* ------------------------------------------------------------ */
/*                  Definitions                                 */
/* ------------------------------------------------------------ */

/*  Register Addresses  */
#define ACL2c_PART_ID_REG        0x02
#define ACL2c_X_DATA_REG         0x08
#define ACL2c_Y_DATA_REG         0x09
#define ACL2c_Z_DATA_REG         0x0A
#define ACL2c_STATUS_REG         0x0B
#define ACL2c_FIFO_ENTRIES_L_REG 0x0C
#define ACL2c_FIFO_ENTRIES_H_REG 0x0D
#define ACL2c_XDATA_L_REG        0x0E
#define ACL2c_XDATA_H_REG        0x0F
#define ACL2c_YDATA_L_REG        0x10
#define ACL2c_YDATA_H_REG        0x11
#define ACL2c_ZDATA_L_REG        0x12
#define ACL2c_ZDATA_H_REG        0x13
#define ACL2c_TEMP_L_REG         0x14
#define ACL2c_TEMP_H_REG         0x15
#define ACL2c_SOFT_RESET_REG     0x1F
#define ACL2c_THRESH_ACT_L_REG   0x20
#define ACL2c_THRESH_ACT_H_REG   0x21
#define ACL2c_TIME_ACT_REG       0x22
#define ACL2c_THRESH_INACT_L_REG 0x23
#define ACL2c_THRESH_INACT_H_REG 0x24
#define ACL2c_TIME_INACT_L_REG   0x25
#define ACL2c_TIME_INACT_H_REG   0x26
#define ACL2c_ACT_INACT_CTL_REG  0x27
#define ACL2c_FIFO_CONTROL_REG   0x28
#define ACL2c_FIFO_SAMPLES_REG   0x29
#define ACL2c_INTMAP1_REG        0x2A
#define ACL2c_INTMAP2_REG        0x2B
#define ACL2c_FILTER_CTL_REG     0x2C
#define ACL2c_POWER_CTL_REG      0x2D
#define ACL2c_SELF_TEST_REG      0x2E

/*  Bit Masks  */
#define ACL2c_STATUS_DATA_READY_MASK     0x01
#define ACL2c_STATUS_FIFO_READY_MASK     0x02
#define ACL2c_STATUS_FIFO_WATERMARK_MASK 0x04
#define ACL2c_STATUS_FIFO_OVERRUN_MASK   0x08
#define ACL2c_STATUS_ACT_MASK            0x10
#define ACL2c_STATUS_INACT_MASK          0x20
#define ACL2c_STATUS_AWAKE_MASK          0x40
#define ACL2c_STATUS_ERR_USER_REGS_MASK  0x80

/*  Command Bytes  */
#define ACL2c_READ      0x0B // Command byte for reading from ACL2
#define ACL2c_WRITE     0x0A // Command byte for writing to ACL2
#define ACL2c_FIFO_READ 0x0D // Command byte for reading from ACL2 FIFO buffer

/*  Initialization Parameters  */
#define ACL2c_FREE_FALL_THRESH   0x96 // Sets free-fall detection threshold to
                                     //    600mg
#define ACL2c_INACT_STILL_THRESH 0xFA // Sets still motion reference threshold to
                                     //    1g
#define ACL2c_FREE_FALL_TIME     0x03 // Sets free-fall detection time to 30ms
#define ACL2c_INACT_STILL_TIME_L 0x10 // Lower half of 10 second still time
#define ACL2c_INACT_STILL_TIME_H 0x27 // Upper half of 10 second still time
#define ACL2c_REF_INACT_ENABLE   0x0C // Enable referenced inactivity detection
#define ACL2c_SET_INACT_INTERUPT 0x20 // Sets the inactivity interrupt to the
                                     //    interrupt 1 pin
#define ACL2c_SENSOR_RANGE_8     0x83 // Sets sensor range to 8g with 100Hz ODR
#define ACL2c_SENSOR_RANGE_4     0x43 // Sets sensor range to 4g with 100Hz ODR
#define ACL2c_SENSOR_RANGE_2     0x03 // Sets sensor range to 2g with 100Hz ODR
#define ACL2c_BEGIN_MEASURE      0x02 // Begins measurement

/*   GPIO Register Offsets  */
#define ACL2c_GPIO_CS_CHANNEL_DATA_OFFSET    0
#define ACL2c_GPIO_CS_CHANNEL_TRIS_OFFSET    4
#define ACL2c_GPIO_INT_CHANNEL_DATA_OFFSET   8
#define ACL2c_GPIO_INT_CHANNEL_TRIS_OFFSET  12

/* ------------------------------------------------------------ */
/*                  Object Class Declarations                   */
/* ------------------------------------------------------------ */

typedef struct ACL2c_SamplePacket {
   int XData;
   int YData;
   int ZData;
   int Temp;
} ACL2c_SamplePacket;

typedef struct PmodACL2c {
   XSpi ACL2Spi;
   u32  GPIO_addr;
   u8   range;
   u16  activeThresh;
   u8   activeTimer;
   u16  inactiveThresh;
   u16  inactiveTimer;
} PmodACL2c;

/* ------------------------------------------------------------ */
/*                  Function Prototypes                         */
/* ------------------------------------------------------------ */

void ACL2c_begin(PmodACL2c *InstancePtr, u32 GPIO_Address, u32 SPI_Address);
void ACL2c_configureMeasureMode(PmodACL2c *InstancePtr);
void ACL2c_configureLinkedMode(PmodACL2c *InstancePtr);
void ACL2c_end(PmodACL2c *InstancePtr);
XStatus ACL2c_SPIInit(XSpi *SpiInstancePtr);

void ACL2c_ReadSpi(PmodACL2c *InstancePtr, u8 reg, u8 *rData, int nData);
void ACL2c_WriteSpi(PmodACL2c *InstancePtr, u8 reg, u8 *wData, int nData);

ACL2c_SamplePacket ACL2c_getSample(PmodACL2c *InstancePtr);

void ACL2c_reset(PmodACL2c *InstancePtr);
void ACL2c_updateRange(PmodACL2c *InstancePtr);

float ACL2c_DataToG(PmodACL2c *InstancePtr, s16 data);
void ACL2c_setRange(PmodACL2c *InstancePtr, int newRange);

u8 ACL2c_getStatus(PmodACL2c *InstancePtr);
int ACL2c_getData(PmodACL2c *InstancePtr, u8 start_reg);

#endif /* SRC_PMODACL2CUSTOM_H_ */
