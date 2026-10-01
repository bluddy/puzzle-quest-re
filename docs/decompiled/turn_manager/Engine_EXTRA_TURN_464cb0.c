
void __thiscall Engine_EXTRA_TURN_464cb0(int param_1,char param_2,char param_3)

{
  undefined4 uVar1;
  undefined4 uVar2;
  int *local_b4;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_0051430b;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  *(char *)(param_1 + 0x32) = param_2;
  if ((param_2 != '\0') && (param_3 != '\0')) {
    if (DAT_005829b8 == (undefined4 *)0x0) {
      DAT_005829b8 = (undefined4 *)FUN_004f0184(0x4c);
      if (DAT_005829b8 == (undefined4 *)0x0) {
        DAT_005829b8 = (undefined4 *)0x0;
      }
      else {
        *DAT_005829b8 = &PTR_LAB_00522274;
      }
    }
    uVar1 = DAT_005829b8[DAT_005829b8[10] + 1];
    uVar2 = uVar1;
    Engine_ADD_GOLD_447c60(uVar1);
    uVar2 = Engine_ADD_GOLD_446200(uVar2);
    Engine_ADD_GOLD_404570(uVar2);
    local_4 = 0;
    (**(code **)(*local_b4 + 0x20))(8,uVar1,0,0);
    Engine_ADD_GOLD_4046a0();
  }
  ExceptionList = local_c;
  return;
}

