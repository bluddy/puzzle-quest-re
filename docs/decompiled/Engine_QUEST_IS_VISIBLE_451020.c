
undefined1 Engine_QUEST_IS_VISIBLE_451020(undefined4 param_1)

{
  undefined1 uVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  undefined4 uVar5;
  
  uVar5 = param_1;
  FUN_00442e40(param_1);
  iVar2 = FUN_00419340(uVar5);
  uVar5 = param_1;
  FUN_0045cf30(param_1);
  iVar3 = FUN_0045ca60(uVar5);
  uVar5 = param_1;
  FUN_004654f0(param_1);
  iVar4 = FUN_0045ca60(uVar5);
  if (iVar2 != 0) {
    return *(undefined1 *)(iVar2 + 0x458);
  }
  if (iVar4 != 0) {
    return *(undefined1 *)(iVar4 + 0x454);
  }
  if (iVar3 != 0) {
    uVar1 = FUN_00450820(param_1);
    return uVar1;
  }
  return 0;
}

