#include "dowhile.h"

int
main (void)
{
  dowhile (0, GOTO_OUT);
  return 0;
}

//# dowhile.c
//  /body/          l+ ## 0
//  /goto-in/       l- ## s-
//  /eval/          l+ ## 0
//  /while-eval/    l+ ## 0
//  /while-in/      l+ ## 0
//  /goto-out/      l+ ## 0
