
void __thiscall Engine_QUEST_ENCOUNTER_CONTINUE_44c2f0(int param_1,char param_2)

{
  *(char *)(param_1 + 0x25) = param_2;
  *(undefined4 *)(param_1 + 0x28) = DAT_0057f484;
  if (param_2 != '\0') {
    *(undefined4 *)(param_1 + 0x14) = *(undefined4 *)(param_1 + 0xc);
    *(undefined4 *)(param_1 + 0x18) = *(undefined4 *)(param_1 + 0x10);
    return;
  }
  if ((*(int *)(param_1 + 0x1c) != 0) && (*(int *)(param_1 + 0x20) != 0)) {
    FUN_00422ec0(*(int *)(param_1 + 0x1c),*(int *)(param_1 + 0x20));
    FUN_00422cb0();
    return;
  }
  FUN_00423510();
  return;
}

