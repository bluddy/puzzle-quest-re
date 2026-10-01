
void __thiscall Engine_QUEST_ADD_RUNE_46cd10(int param_1,undefined4 param_2)

{
  undefined4 uVar1;
  int iVar2;
  
  uVar1 = param_2;
  iVar2 = FUN_00431d70(param_2);
  if (iVar2 == 0) {
    param_2 = uVar1;
    FUN_0046bc20(&param_2);
  }
  *(undefined1 *)(param_1 + 0xbc) = 1;
  return;
}

