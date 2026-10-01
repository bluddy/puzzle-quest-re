
void Lua_GET_CURRENT_RUNE_BASEDATA(undefined4 param_1)

{
  undefined4 uVar1;
  uint3 uVar2;
  undefined2 uVar4;
  int iVar3;
  longlong lVar5;
  undefined8 uVar6;
  byte bVar7;
  undefined2 uStack_a;
  
  iVar3 = Engine_GET_CURRENT_RUNE_CODE_44f8e0();
  if ((*(int *)(iVar3 + 0x5c) == 0) || (*(int *)(iVar3 + 0x60) - *(int *)(iVar3 + 0x5c) >> 2 == 0))
  {
    uVar4 = 0;
  }
  else {
    uVar4 = (undefined2)((uint)*(undefined4 *)(*(int *)(iVar3 + 0x60) + -4) >> 8);
  }
  bVar7 = (byte)((ushort)uVar4 >> 8);
  uVar2 = CONCAT12(bVar7,uVar4) & 0xff00ff;
  lVar5 = (ulonglong)uVar2 << 0x20;
  FUN_00460a80(0,(uint)uVar2);
  FUN_0045f240(lVar5);
  FUN_00460a80();
  iVar3 = FUN_0045f070();
  uVar1 = CONCAT22(uStack_a,(ushort)bVar7);
  uVar6 = CONCAT44(uVar1,1);
  FUN_00460a80(1,uVar1,*(undefined4 *)(iVar3 + 0x34));
  FUN_0045f240(uVar6);
  FUN_00460a80();
  FUN_0045f0a0();
  iVar3 = FUN_0050432c();
  FUN_004f7020(param_1,(double)iVar3);
  FUN_005042e3();
  return;
}

