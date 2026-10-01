
void __thiscall Engine_ADD_TEMP_SKILL_465f60(int *param_1,int param_2,int param_3)

{
  int iVar1;
  
  if (param_2 == 7) {
    param_3 = 6;
  }
  else if (param_2 == 6) {
    param_3 = 5;
  }
  else if (param_2 == 5) {
    param_3 = 4;
  }
  iVar1 = (**(code **)(*param_1 + 0x20))(5,param_1[param_3 + 0x12],param_1[0x11],param_3);
  if (999 < iVar1) {
    iVar1 = 999;
  }
  Engine_ADD_TEMP_SKILL_478620(param_2,iVar1);
  return;
}

