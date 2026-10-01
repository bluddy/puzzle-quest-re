
void __thiscall FUN_0047a6c0(int param_1,int *param_2)

{
  int iVar1;
  
  if ((char)param_2[2] == '\0') {
    iVar1 = 0;
    if (0 < param_2[3]) {
      do {
        *(undefined1 *)(iVar1 + *param_2 * 9 + param_1 + 0x3e4 + param_2[1]) = 1;
        iVar1 = iVar1 + 1;
      } while (iVar1 < param_2[3]);
    }
  }
  else {
    iVar1 = 0;
    if (0 < param_2[3]) {
      do {
        *(undefined1 *)(param_1 + (*param_2 + iVar1) * 9 + 0x3e4 + param_2[1]) = 1;
        iVar1 = iVar1 + 1;
      } while (iVar1 < param_2[3]);
      return;
    }
  }
  return;
}

