/******************************************************************************/
/*                                                                            */
/* PmodACL2custom.c -- Driver source for the PmodACL2                               */
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

/***************************** Include Files *******************************/

#include "PmodACL2custom.h"

/************************** Function Definitions ***************************/

XSpi_Config ACL2Config =
{
   0,
   0,
   1,
   0,
   1,
   8,
   0,
   0,
   0,
   0,
   0
};

/* ------------------------------------------------------------ */
/*** void ACL2c_begin(PmodACL2c *InstancePtr, u32 GPIO_Address, u32 SPI_Address)
**
**   Parameters:
**      InstancePtr:  A PmodACL2 device to start
**      GPIO_Address: The Base address of the PmodACL2 GPIO
**      SPI_Address:  The Base address of the PmodACL2 SPI
**
**   Return Value:
**      None
**
**   Description:
**      Initialize the PmodACL2
*/
void ACL2c_begin(PmodACL2c *InstancePtr, u32 GPIO_Address, u32 SPI_Address) {
   // Set up device addresses
   InstancePtr->GPIO_addr = GPIO_Address;
   ACL2Config.BaseAddress = SPI_Address;

   // Set up GPIO channels
   Xil_Out32(InstancePtr->GPIO_addr + ACL2c_GPIO_CS_CHANNEL_TRIS_OFFSET, 0x0);
   Xil_Out32(InstancePtr->GPIO_addr + ACL2c_GPIO_CS_CHANNEL_DATA_OFFSET, 0x1);

   // 0b1111 for input, 0b0000 for output, 0b0001 for pin1 in pin 2 out etc.
   Xil_Out32(InstancePtr->GPIO_addr + ACL2c_GPIO_INT_CHANNEL_TRIS_OFFSET, 0x3);

   //initialize SPI device
   ACL2c_SPIInit(&InstancePtr->ACL2Spi);

   // Initialize defaults for Linked Mode configuration
   InstancePtr->activeThresh = 0x0020;
   InstancePtr->activeTimer = 0x64;
   InstancePtr->inactiveThresh = 0x001A;
   InstancePtr->inactiveTimer = 0x0064;
}

void ACL2c_configureMeasureMode(PmodACL2c *InstancePtr) {
   u8 value[7];

   // Configure the Activity and Inactivity thresholds and timers.
   value[0] = 0x14; // Activity threshold is 0x0014
   value[1] = 0x00;
   value[2] = 0x64; // Activity timer is 0x64 at 100 Hz
   value[3] = 0x10; // Inactivity threshold is 0x0010
   value[4] = 0x00;
   value[5] = 0x64; // Inactivity timer is 0x64 at 100 Hz
   value[6] = 0x00;
   ACL2c_WriteSpi(InstancePtr, ACL2c_THRESH_ACT_L_REG, &value[0], 7);

   value[0] = 0x5; // Enable the activity and inactivity functionality with absolute measurements.
   ACL2c_WriteSpi(InstancePtr, ACL2c_ACT_INACT_CTL_REG, &value[0], 1);

   value[0] = 0x00; // Disable FIFO
   value[1] = 0x00; // Disable FIFO samples
   ACL2c_WriteSpi(InstancePtr, ACL2c_FIFO_CONTROL_REG, &value[0], 2);

   // Set sensor range to 2g with 100Hz ODR, with Half Bandwidth filtering
   value[0] = ACL2c_SENSOR_RANGE_2 | 0x10;
   ACL2c_WriteSpi(InstancePtr, ACL2c_FILTER_CTL_REG, &value[0], 1);

   // Begins measurement and configures for ultra-low noise.
   value[0] = ACL2c_BEGIN_MEASURE | 0x20;
   ACL2c_WriteSpi(InstancePtr, ACL2c_POWER_CTL_REG, &value[0], 1);

   // Set the range internal class variable
   ACL2c_updateRange(InstancePtr);
}

void ACL2c_configureLinkedMode(PmodACL2c *InstancePtr) {
   u8 value[7];

   // Configure the Activity and Inactivity thresholds and timers.
   value[0] = (u8)(InstancePtr->activeThresh & 0xFF); // Activity threshold Low
   value[1] = (u8)(InstancePtr->activeThresh >> 8); // Activity threshold High
   value[2] = (InstancePtr->activeTimer); // Activity timer
   value[3] = (u8)(InstancePtr->inactiveThresh & 0xFF); // Inactivity threshold Low
   value[4] = (u8)(InstancePtr->inactiveThresh >> 8); // Inactivity threshold High
   value[5] = (u8)(InstancePtr->inactiveTimer & 0xFF); // Inactivity timer Low
   value[6] = (u8)(InstancePtr->inactiveTimer >> 8); // Inactivity timer High

   ACL2c_WriteSpi(InstancePtr, ACL2c_THRESH_ACT_L_REG, &value[0], 7);

   value[0] = 0x1F; // Enable the linked mode, and activity and inactivity functionality with relative measurements.
   ACL2c_WriteSpi(InstancePtr, ACL2c_ACT_INACT_CTL_REG, &value[0], 1);

   value[0] = 0x00; // Disable FIFO
   value[1] = 0x00; // Disable FIFO samples
   ACL2c_WriteSpi(InstancePtr, ACL2c_FIFO_CONTROL_REG, &value[0], 2);

   // Set sensor range to 2g with 100Hz ODR, with Half Bandwidth filtering
   value[0] = ACL2c_SENSOR_RANGE_2 | 0x10;
   ACL2c_WriteSpi(InstancePtr, ACL2c_FILTER_CTL_REG, &value[0], 1);

   // Begins measurement and configures for ultra-low noise.
   value[0] = ACL2c_BEGIN_MEASURE | 0x20;
   ACL2c_WriteSpi(InstancePtr, ACL2c_POWER_CTL_REG, &value[0], 1);

   // Set the range internal class variable
   ACL2c_updateRange(InstancePtr);
}

/* ------------------------------------------------------------ */
/*** ACL2c_end(void)
**
**   Parameters:
**      InstancePtr: PmodACL2 device to stop
**
**   Return Value:
**      None
**
**   Errors:
**      None
**
**   Description:
**      Stops the device
*/
void ACL2c_end(PmodACL2c *InstancePtr) {
   XSpi_Stop(&InstancePtr->ACL2Spi);
}

/* ------------------------------------------------------------ */
/*** XStatus ACL2c_SPIInit(XSpi *SpiInstancePtr)
**
**   Parameters:
**      SpiInstancePtr: XSpi device to initialize
**
**   Return Value:
**      Success or failure status of the initialization process
**
**   Description:
**      Initializes the PmodACL2 SPI
*/
XStatus ACL2c_SPIInit(XSpi *SpiInstancePtr) {
   int Status;

   Status = XSpi_CfgInitialize(SpiInstancePtr, &ACL2Config,
         ACL2Config.BaseAddress);
   if (Status != XST_SUCCESS) {
      return XST_FAILURE;
   }

   u32 options = XSP_MASTER_OPTION | XSP_CLK_ACTIVE_LOW_OPTION
         | XSP_CLK_PHASE_1_OPTION | XSP_MANUAL_SSELECT_OPTION;
   Status = XSpi_SetOptions(SpiInstancePtr, options);
   if (Status != XST_SUCCESS) {
      return XST_FAILURE;
   }

   Status = XSpi_SetSlaveSelect(SpiInstancePtr, 1);
   if (Status != XST_SUCCESS) {
      return XST_FAILURE;
   }

   // Start the SPI driver so that the device is enabled.
   XSpi_Start(SpiInstancePtr);

   // Disable Global interrupt to use polled mode operation
   XSpi_IntrGlobalDisable(SpiInstancePtr);

   return XST_SUCCESS;
}

/* ------------------------------------------------------------ */
/*** void ACL2c_WriteSpi(PmodACL2c *InstancePtr, u8 reg, u8 *wData, int nData)
**
**   Parameters:
**      InstancePtr: PmodACL2 device to communicate with
**      reg:         Starting register to write to
**      wData:       Array of data to write
**      nData:       Number of data bytes to write
**
**   Return Value:
**      none
**
**   Description:
**      Writes the byte array to the chip via SPI. It will write the first byte
**      into the specified register, then the next into the following register
**      until all of the data has been sent.
*/
void ACL2c_WriteSpi(PmodACL2c *InstancePtr, u8 reg, u8 *wData, int nData) {
   u8 bytearray[nData + 2];
   int i;

   bytearray[0] = ACL2c_WRITE; // write command
   bytearray[1] = reg;
   for (i = 0; i < nData; i++)
      bytearray[i + 2] = wData[i];

   Xil_Out32(InstancePtr->GPIO_addr + ACL2c_GPIO_CS_CHANNEL_DATA_OFFSET, 0x0);
   XSpi_Transfer(&InstancePtr->ACL2Spi, bytearray, bytearray, nData + 2);
   Xil_Out32(InstancePtr->GPIO_addr + ACL2c_GPIO_CS_CHANNEL_DATA_OFFSET, 0x1);
}

/* ------------------------------------------------------------ */
/*** void ACL2c_ReadSpi(PmodACL2c *InstancePtr, u8 reg, u8 *rData, int nData)
**
**   Parameters:
**      InstancePtr: PmodACL2 device to communicate with
**      reg:         Starting register to read from
**      rData:       Byte array to read into, minimum size of nData
**      nData:       Number of data bytes to read
**
**   Return Value:
**      The contents of the reg register and next nData - 1 consecutive
**      registers through rData
**
**   Description:
**      Reads data in through SPI. It will read the first byte from the
**      starting register, then the next from the following register.
**
**      Data is stored into rData.
**
**      We are bit-banging the CS pin of the SPI connection as the manual-mode
**      slave-select in the Xilinx driver appears to not be totally functional.
*/
void ACL2c_ReadSpi(PmodACL2c *InstancePtr, u8 reg, u8 *rData, int nData) {
   u8 bytearray[nData + 2];
   int i;

   bytearray[0] = 0x0B; // Read command
   bytearray[1] = reg;
   bytearray[2] = 0;

   Xil_Out32(InstancePtr->GPIO_addr + ACL2c_GPIO_CS_CHANNEL_DATA_OFFSET, 0x0);
   XSpi_Transfer(&InstancePtr->ACL2Spi, bytearray, bytearray, nData + 2);
   Xil_Out32(InstancePtr->GPIO_addr + ACL2c_GPIO_CS_CHANNEL_DATA_OFFSET, 0x1);

   for (i = 0; i < nData; i++)
      rData[i] = bytearray[i + 2];
}

/* ------------------------------------------------------------ */
/*** int ACL2c_RawToInt(u8 buf[2])
**
**   Parameters:
**      buf: Results of a SPI read operation from the ACL2, typically a sample
**           from TEMP, X, Y, or Z registers
**
**   Return Value:
**      integer
**
**   Description:
**      Converts an 11 bit sign-extended register-pair reading from the ACL2
**      into an integer
*/
int ACL2c_RawToInt(u8 buf[2]) {
   u16 data;
   data = (((u16) buf[1] << 8) | buf[0]);
   if ((data & 0x8000) != 0)
      // Complete sign extension before converting to int
      return (int) ((u32) data | 0xFFFF0000);
   else
      return (int) data;
}

/* ------------------------------------------------------------ */
/*** ACL2c_SamplePacket ACL2c_getSample(PmodACL2c *InstancePtr)
**
**   Parameters:
**      InstancePtr: The PmodACL2 device to communicate with
**
**   Return Value:
**      X, Y, Z data in LSB units packed into an ACL2c_SamplePacket struct
**
**   Description:
**      Captures an XYZ accelerometer data sample
*/
ACL2c_SamplePacket ACL2c_getSample(PmodACL2c *InstancePtr) {
   ACL2c_SamplePacket result;
   u8 buf[8];

   // All data registers are contiguous in the ACL2 memory space, starting at
   // XDATA_L
   ACL2c_ReadSpi(InstancePtr, ACL2c_XDATA_L_REG, buf, 8);
   result.XData = ACL2c_RawToInt(&buf[0]);
   result.YData = ACL2c_RawToInt(&buf[2]);
   result.ZData = ACL2c_RawToInt(&buf[4]);
   result.Temp = ACL2c_RawToInt(&buf[6]);
   return result;
}

/* ------------------------------------------------------------ */
/*** int ACL2c_getTemp(PmodACL2c *InstancePtr)
**
**   Parameters:
**      InstancePtr: The PmodACL2 device to communicate with
**
**   Return Value:
**      result - integer value of the read temperature data
**
**   Errors:
**      Is not accurate. Needs calibration.
**
**   Description:
**      Calls ACL2c_getData with the TEMP_H and TEMP_L registers and returns that
**      value
*/
int ACL2c_getTemp(PmodACL2c *InstancePtr) {
   return ACL2c_getData(InstancePtr, ACL2c_TEMP_L_REG);;
}

/* ------------------------------------------------------------ */
/*** u8 ACL2c_getStatus(PmodACL2c *InstancePtr)
**
**   Parameters:
**      InstancePtr: The PmodACL2 device to take measurement from
**
**   Return Value:
**      result: 8 bit contents of the status register
**
**   Description:
**      Read from the STATUS register and return its value
*/
u8 ACL2c_getStatus(PmodACL2c *InstancePtr) {
   u8 regRead = 0;
   // Get the data from the STATUS register
   ACL2c_ReadSpi(InstancePtr, ACL2c_STATUS_REG, &regRead, 1);
   return regRead;
}

/* ------------------------------------------------------------ */
/*** int ACL2c_getData(PmodACL2c *InstancePtr, u8 start_reg)
**
**   Parameters:
**      InstancePtr: The PmodACL2 device
**      start_reg:   The low byte register of the target pair
**
**   Return Value:
**      result: Signed integer value of the data in the register pair
**
**   Description:
**      Retrieves the 11 bit x, y, z, or temperature values that come from 2
**      consecutive data registers
*/
int ACL2c_getData(PmodACL2c *InstancePtr, u8 start_reg) {
   u8 buffer[2] = {0, 0};

   // Store XData high into result
   // Store XData low into 8 LSB
   ACL2c_ReadSpi(InstancePtr, start_reg, buffer, 2);

   return ACL2c_RawToInt(buffer);
}

/* ------------------------------------------------------------ */
/*** void ACL2c_reset(PmodACL2c *InstancePtr)
**
**   Parameters:
**      InstancePtr: The PmodACL2 device
**
**   Return Value:
**      None
**
**   Description:
**      Writes the byte 'R' to the reset register to initiate a soft reset.
*/
void ACL2c_reset(PmodACL2c *InstancePtr) {
   u8 write = 'R';
   ACL2c_WriteSpi(InstancePtr, ACL2c_SOFT_RESET_REG, &write, 1);
}

/* ------------------------------------------------------------ */
/*** void ACL2c_updateRange(PmodACL2c *InstancePtr)
**
**   Parameters:
**      InstancePtr: The PmodACL2 device
**
**   Return Value:
**      none
**
**   Description:
**      Reads the filter control register and stores the sensitivity range into
**      the range variable inside of the PmodACL2 device
*/
void ACL2c_updateRange(PmodACL2c *InstancePtr) {
   uint8_t value;
   ACL2c_ReadSpi(InstancePtr, ACL2c_FILTER_CTL_REG, &value, 1);

   // Only looking at first two bits
   value &= 0xC0;

   // Set range based on register value
   switch (value) {
   case 0xC0:
   case 0x80:
      InstancePtr->range = 8;
      break;

   case 0x40:
      InstancePtr->range = 4;
      break;

   case 0x00:
      InstancePtr->range = 2;
      break;
   }
}

/* ------------------------------------------------------------ */
/*** ACL2c_setRange(PmodACL2c *InstancePtr, int newRange)
**
**   Parameters:
**      InstancePtr: The PmodACL2 device
**      newRange:    The new sensitivity range for the ACL to use (2,4,8)
**
**   Return Value:
**      none
**
**   Description:
**      Takes in the user choice newRange and if it is valid, writes to the
**      filter control to change the sensitivity range while keeping other
**      filter preferences
*/
void ACL2c_setRange(PmodACL2c *InstancePtr, int newRange) {
   uint8_t temp = 0;

   // Get range control data
   ACL2c_ReadSpi(InstancePtr, ACL2c_FILTER_CTL_REG, &temp, 1);

   // Modify the temp data to change to desired range
   switch (newRange) {
   case 2:
      temp = temp & 0x3F; // Set top two bits to 0b00
      break;
   case 4:
      temp = temp & 0x3F;
      temp = temp | 0x40; // Set top two bits to 0b01
      break;
   case 8:
      temp = temp | 0x80; // Set top bit to 0b1
      break;
   default:
      break; // If not a valid range, will just set the FILTER_CTL register to
             // what it was
   }

   // Write modified temp back to FILTER_CTL
   ACL2c_WriteSpi(InstancePtr, ACL2c_FILTER_CTL_REG, &temp, 1);

   // Set class range value
   ACL2c_updateRange(InstancePtr);
}

/* ------------------------------------------------------------ */
/*** float ACL2c_DataToG(PmodACL2c *InstancePtr, int data)
**
**   Parameters:
**      InstancePtr: The PmodACL2 device
**      data:        ACL2 reading in units of LSB as determined by ACL2
**                   configuration
**
**  Return Value:
**      data converted to units of g
**
**  Description:
**      Converts an ACL2 reading in LSB units to g
*/
float ACL2c_DataToG(PmodACL2c *InstancePtr, s16 data) {
   switch (InstancePtr->range) {
   case 2:
      return ((float) data) / 1000.0;
   case 4:
      return ((float) data) / 500.0;
   case 8:
      return ((float) data) / 250.0;
   default:
      return 0.0;
   }
}
