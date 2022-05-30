
#ifndef PWM_H
#define PWM_H

/* Note that this source file originates from the Digilent Inc.
 * GitHub Vivado Library, available at:
 * https://github.com/DigilentInc/vivado-library
 *
 * The intent of this header is to disable PWM functionality
 * by converting all PWM function calls to no-operation,
 * rather than remove the PWM functionality from the
 * application using the PWM driver.
 */
/****************** Include Files ********************/
#include "xil_types.h"
#include "xstatus.h"

#define PWM_AXI_CTRL_REG_OFFSET 0
#define PWM_AXI_PERIOD_REG_OFFSET 8
#define PWM_AXI_DUTY_REG_OFFSET 64

/** Substitute declarations that are pertinent when the PWM driver is not
 * included in the FPGA BSP.
 */
#define XPAR_PWM_0_PWM_AXI_BASEADDR 0x00000000UL
#define XPAR_PWM_1_PWM_AXI_BASEADDR 0x00000000UL

/**************************** Type Definitions *****************************/
/**
 *
 * Write a value to a PWM register. A 32 bit write is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is written.
 *
 * @param   BaseAddress is the base address of the PWMdevice.
 * @param   RegOffset is the register offset from the base to write to.
 * @param   Data is the data written to the register.
 *
 * @return  None.
 *
 * @note
 * C-style signature:
 * 	void PWM_mWriteReg(u32 BaseAddress, unsigned RegOffset, u32 Data)
 *
 */
#define PWM_mWriteReg(BaseAddress, RegOffset, Data) \
		{while(0) {}}

/**
 *
 * Read a value from a PWM register. A 32 bit read is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is read from the register. The most significant data
 * will be read as 0.
 *
 * @param   BaseAddress is the base address of the PWM device.
 * @param   RegOffset is the register offset from the base to write to.
 *
 * @return  Data is the data from the register.
 *
 * @note
 * C-style signature:
 * 	u32 PWM_mReadReg(u32 BaseAddress, unsigned RegOffset)
 *
 */
#define PWM_mReadReg(BaseAddress, RegOffset) \
    {while(0) {}}

/************************** Function Prototypes ****************************/
/**
 *
 * Run a self-test on the driver/device. Note this may be a destructive test if
 * resets of the device are performed.
 *
 * If the hardware system is not built correctly, this function may never
 * return to the caller.
 *
 * @param   baseaddr_p is the base address of the PWM instance to be worked on.
 *
 * @return
 *
 *    - XST_SUCCESS   if all self-test code passed
 *    - XST_FAILURE   if any self-test code failed
 *
 * @note    Caching must be turned off for this function to work.
 * @note    Self test may fail if data memory and device are not on the same bus.
 *
 */
#define PWM_Reg_SelfTest(p) \
		(0)

#define PWM_Set_Period(baseAddr, clocks) \
	{while(0) {}}

#define PWM_Set_Duty(baseAddr, clocks, pwmIndex) \
	{while(0) {}}

#define PWM_Get_Period(baseAddr) \
	{0}

#define PWM_Get_Duty(baseAddr, pwmIndex) \
	{0}

#define PWM_Enable(baseAddr) \
	{while(0) {}}

#define PWM_Disable(baseAddr) \
	{while(0) {}}

#endif // PWM_H
