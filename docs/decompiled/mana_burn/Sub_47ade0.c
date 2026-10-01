
void __thiscall FUN_0047ade0(int param_1,int *param_2,int *param_3)

{
  int iVar1;
  char *pcVar2;
  char *pcVar3;
  int iVar4;
  
  iVar4 = 0;
  pcVar3 = (char *)(param_1 + 8);
  do {
    iVar1 = 0;
    pcVar2 = pcVar3;
    do {
      if (*pcVar2 != '\0') {
        *param_2 = iVar1;
        *param_3 = iVar4;
        return;
      }
      iVar1 = iVar1 + 1;
      pcVar2 = pcVar2 + 0x48;
    } while (iVar1 < 8);
    iVar4 = iVar4 + 1;
    pcVar3 = pcVar3 + 8;
  } while (iVar4 < 9);
  *param_2 = -1;
  *param_3 = -1;
  return;
}

