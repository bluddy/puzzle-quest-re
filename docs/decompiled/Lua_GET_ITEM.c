
void Lua_GET_ITEM(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  int *piVar3;
  int iVar4;
  char *pcVar5;
  byte bStack_36;
  byte bStack_35;
  undefined1 auStack_34 [12];
  undefined1 auStack_28 [12];
  ushort uStack_1c;
  ushort uStack_1a;
  ushort uStack_18;
  ushort uStack_16;
  undefined2 uStack_14;
  undefined4 uStack_10;
  void *pvStack_c;
  undefined *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &DAT_00515e00;
  pvStack_c = ExceptionList;
  uStack_10 = DAT_0057faa0;
  ExceptionList = &pvStack_c;
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar5 = "GET_ITEM: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_ITEM: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
  }
  else {
    FUN_004f6db0(param_1,1);
    uVar2 = FUN_0050432c();
    iVar1 = FUN_004f6ca0(param_1,2);
    if (iVar1 == 0) {
      pcVar5 = "GET_ITEM: arg 2 is not an integer";
      Engine_ACTIVATE_COMPANION_483650("GET_ITEM: arg 2 is not an integer");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
    }
    else {
      FUN_004f6db0(param_1,2);
      iVar1 = FUN_0050432c();
      Engine_ADD_GOLD_447c60(uVar2);
      piVar3 = (int *)Engine_ADD_GOLD_446200(uVar2);
      iVar1 = *(int *)(*piVar3 + 0x9c + iVar1 * 4);
      if (iVar1 < 0) {
        Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
        uStack_4 = 1;
        FUN_00483af0(param_1,auStack_34);
      }
      else {
        iVar4 = Engine_GET_CURRENT_RUNE_CODE_44f8e0();
        iVar1 = iVar1 * 0x40 + *(int *)(iVar4 + 8);
        uStack_1c = (ushort)*(undefined4 *)(iVar1 + 4) & 0xff;
        uStack_1a = (ushort)*(byte *)(iVar1 + 5);
        bStack_36 = (byte)((uint)*(undefined4 *)(iVar1 + 4) >> 0x10);
        uStack_18 = (ushort)bStack_36;
        bStack_35 = (byte)((uint)*(undefined4 *)(iVar1 + 4) >> 0x18);
        uStack_16 = (ushort)bStack_35;
        uStack_14 = 0;
        Engine_ACTIVATE_COMPANION_4be530(&uStack_1c,0xffffffff);
        uStack_4 = 0;
        FUN_00483af0(param_1,auStack_28);
      }
      uStack_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
  }
  ExceptionList = pvStack_c;
  FUN_005042e3();
  return;
}

