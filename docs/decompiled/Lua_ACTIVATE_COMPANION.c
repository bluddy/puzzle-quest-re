
undefined4 Lua_ACTIVATE_COMPANION(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  ushort *puVar3;
  ushort *puVar4;
  ushort *puVar5;
  ushort *puVar6;
  uint uVar7;
  char *pcVar8;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  FUN_004be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar1 = FUN_004f6d00(param_1,1);
  if (iVar1 == 0) {
    pcVar8 = "ACTIVATE_COMPANION: arg 1 is not a string";
    FUN_00483650("ACTIVATE_COMPANION: arg 1 is not a string");
    FUN_004836e0(pcVar8);
    local_4 = 0xffffffff;
    FUN_004bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar2 = FUN_004f6e50(param_1,1);
  FUN_004bf1a0(uVar2);
  puVar3 = (ushort *)FUN_004be7e0(3);
  puVar4 = (ushort *)FUN_004be7e0(2);
  puVar5 = (ushort *)FUN_004be7e0(1);
  puVar6 = (ushort *)FUN_004be7e0(0);
  uVar7 = (((uint)*puVar3 << 8 | (uint)*puVar4) << 8 | (uint)*puVar5) << 8 | (uint)*puVar6;
  FUN_00443cb0(uVar7);
  FUN_00443270(uVar7);
  local_4 = 0xffffffff;
  FUN_004bdf40();
  ExceptionList = local_c;
  return 0;
}

