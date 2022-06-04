/*------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020 Timothy Stotts
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
------------------------------------------------------------------------------*/
/**-----------------------------------------------------------------------------
 * @file freertos_acl2_main.c
 *
 * @brief A SoPC top-level design with the PMOD ACL2 driver.
 * This design operates the Pmod ACL2 in either Measurement Mode or Linked Mode
 * to stream accelerometer measurements to the Pmod CLS display, or to display
 * motion values at the point of crossing an activity event threshold.
 *
 * @author
 * Timothy Stotts (timothystotts08@gmail.com)
 *
 * @copyright
 * (c) 2020 Copyright Timothy Stotts
 *
 * This program is free software; distributed under the terms of the MIT
 * License.
------------------------------------------------------------------------------*/

/* FreeRTOS includes. */
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "timers.h"
/* Xilinx includes. */
#include <string.h>
#include <stdio.h>
#include "sleep.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xgpio.h"
/* Project includes. */
#include "PmodCLS.h"
#include "PmodACL2custom.h"
#include "Experiment.h"

/*-----------------------------------------------------------*/

/* Task handles for controlling real-time tasks */
static TaskHandle_t xClsTask;
static TaskHandle_t xAcl2Task;
static TaskHandle_t xPrintTask;

/* Queues for generating update events */
QueueHandle_t xQueuePrint = NULL;
QueueHandle_t xQueueClsDispl = NULL;

/* The real-time tasks of this program. */
static void prvClsTask( void *pvParameters ); /* Print to PMOD CLS on events */
static void prvAcl2Task( void *pvParameters ); /* Master task, operate PMOD ACL2 and generate events. */
static void prvPrintTask( void *pvParameters ); /* Print to UARTlite on events */

int main(void)
{
	/* Create a task to receive 16x2 text line updates to the external dot-matrix LCD of the PMOD CLS. */
	xTaskCreate( prvClsTask,
				 (const char*) "CLS",
				 configMINIMAL_STACK_SIZE,
				 NULL,
				 tskIDLE_PRIORITY,
				 &xClsTask );

	/* Create a task to read updates from the PMOD ACL2, and send queue updates for LED, CLS, Printf . */
	xTaskCreate( prvAcl2Task,
				 (const char*) "ACL2",
				 configMINIMAL_STACK_SIZE + 1024,
				 NULL,
				 tskIDLE_PRIORITY + 2,
				 &xAcl2Task);

	/* Create a task to receive strings to print to the UART via xil_printf(). */
	xTaskCreate( prvPrintTask,
				 ( const char * ) "PRINT",
				 configMINIMAL_STACK_SIZE,
				 NULL,
				 tskIDLE_PRIORITY + 1,
				 &xPrintTask );

	/* Create the 16x2 dot-matrix LCD display receiving text updates queue. */
	xQueueClsDispl = xQueueCreate(2, sizeof(t_cls_lines));

	/* Create the serial console printf() queue for short strings to print to console. */
	xQueuePrint = xQueueCreate(4, PRINTF_BUF_SZ);

	/* Check the queue was created. */
	configASSERT(xQueueClsDispl);

	/* Check the queue was created. */
	configASSERT(xQueuePrint);

	/* Start the tasks and timer running. */
	vTaskStartScheduler();

	/* If all is well, the scheduler will now be running, and the following line
	will never be reached.  If the following line does execute, then there was
	insufficient FreeRTOS heap memory available for the idle and/or timer tasks
	to be created.  See the memory management section on the FreeRTOS web site
	for more details. */
	for( ;; );
}

/*-----------------------------------------------------------*/
static void prvClsTask( void *pvParameters )
{
	static PmodCLS clsDevice;
	t_cls_lines clsLines;

	/* Initialize the PMOD CLS 16x2 dot-matrix LCD display. */
	memset(&clsDevice, 0x00, sizeof(clsDevice));
	CLS_begin(&clsDevice, XPAR_PMODCLS_0_AXI_LITE_SPI_BASEADDR);

	/* Clear the display. */
	CLS_DisplayClear(&clsDevice);

	for (;;) {
		/* Block on CLS lines queue to receive the next incoming display text update. */
		xQueueReceive(xQueueClsDispl, &clsLines, portMAX_DELAY);

		if ((strnlen(clsLines.line1, 16) == 0) && (strnlen(clsLines.line2, 16) == 0)) {
			/* If both lines are only null strings, then clear the display and print nothing. */
			CLS_DisplayClear(&clsDevice);
		} else {
			/* Otherwise, clear the display and print the two lines of text. */
			CLS_DisplayClear(&clsDevice);
			CLS_WriteStringAtPos(&clsDevice, 0, 0, clsLines.line1);
			CLS_WriteStringAtPos(&clsDevice, 1, 0, clsLines.line2);
		}
	}
}

/*-----------------------------------------------------------*/
static void prvAcl2Task( void *pvParameters )
{
	Experiment_prvAcl2Task(pvParameters);
}

/*-----------------------------------------------------------*/
static void prvPrintTask( void *pvParameters )
{
	char Recdstring[PRINTF_BUF_SZ] = "";

	for( ;; )
	{
		/* Block to wait for data arriving on the queue. */
		xQueueReceive( 	xQueuePrint,				/* The queue being read. */
						Recdstring,	/* Data is read into this address. */
						portMAX_DELAY );	/* Wait without a timeout for data. */

		/* Print the received data. */
		xil_printf( "%s\r\n", Recdstring );
	}
}

