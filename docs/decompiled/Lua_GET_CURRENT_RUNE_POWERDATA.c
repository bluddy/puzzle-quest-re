
void Lua_GET_CURRENT_RUNE_POWERDATA(undefined4 param_1)

{
  undefined4 uVar1;
  int iVar2;
  undefined8 uVar3;
  uint uVar4;
  undefined2 uVar5;
  byte bVar6;
  undefined2 uStack_8;
  
  iVar2 = Engine_GET_CURRENT_RUNE_CODE_44f8e0();
  if ((*(int *)(iVar2 + 0x5c) == 0) || (*(int *)(iVar2 + 0x60) - *(int *)(iVar2 + 0x5c) >> 2 == 0))
  {
    uVar5 = 0;
  }
  else {
    uVar5 = (undefined2)((uint)*(undefined4 *)(*(int *)(iVar2 + 0x60) + -4) >> 0x10);
  }
  bVar6 = (byte)((ushort)uVar5 >> 8);
  uVar1 = CONCAT22(uStack_8,(ushort)bVar6);
  uVar3 = CONCAT44(uVar1,2);
  Engine_GET_CURRENT_RUNE_BASEDATA_460a80(2,uVar1);
  Engine_GET_CURRENT_RUNE_BASEDATA_45f240(uVar3);
  Engine_GET_CURRENT_RUNE_BASEDATA_460a80();
  iVar2 = FUN_0045f0f0();
  uVar4 = (uint)(CONCAT12(bVar6,uVar5) & 0xff00ff);
  uVar3 = CONCAT44(uVar4,1);
  Engine_GET_CURRENT_RUNE_BASEDATA_460a80(1,uVar4,*(undefined4 *)(iVar2 + 0x40));
  Engine_GET_CURRENT_RUNE_BASEDATA_45f240(uVar3);
  Engine_GET_CURRENT_RUNE_BASEDATA_460a80();
  Engine_GET_CURRENT_RUNE_BASEDATA_45f0a0();
  iVar2 = FUN_0050432c();
  FUN_004f7020(param_1,(double)iVar2);
  FUN_005042e3();
  return;
}

