
void __thiscall Save_EnumerateHeroes_46cd00(int param_1,undefined4 param_2)

{
  int iVar1;
  undefined4 local_8;
  ushort local_4;
  undefined1 local_2;
  
  iVar1 = Engine_QUEST_COMPANION_MESSAGE_408b90(param_2);
  if (iVar1 == 0) {
    local_8 = param_2;
    iVar1 = Engine_QUEST_COMPANION_MESSAGE_419060();
    local_2 = iVar1 < 8;
    local_4 = (ushort)(byte)local_2;
    FUN_0046bb90(&local_8);
  }
  *(undefined1 *)(param_1 + 0xbc) = 1;
  return;
}

