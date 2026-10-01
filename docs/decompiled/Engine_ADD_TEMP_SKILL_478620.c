
int Engine_ADD_TEMP_SKILL_478620(undefined4 param_1,int param_2)

{
  int iVar1;
  
  switch(param_1) {
  case 3:
    return (param_2 + 1) / 2;
  case 4:
    iVar1 = FUN_004785c0(param_2);
    return iVar1;
  default:
    FUN_004786b0(param_1,param_2);
    iVar1 = FUN_0050432c();
    return iVar1;
  case 7:
    return (param_2 * 3) / 2;
  case 10:
    return param_2 / 0x14;
  }
}

