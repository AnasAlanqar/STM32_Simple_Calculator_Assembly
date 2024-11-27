// main.c
#include "test22.h"

extern void asm_main(void);  // Declare the assembly function

int main(void)
{
    asm_main();  // Call our assembly function
    while(1);  {

    }  // Should never return
    return 0;
}
