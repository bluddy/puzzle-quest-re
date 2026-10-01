
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __fastcall Engine_QUEST_CONVERSATION_44c7d0(int param_1)

{
  if (*(char *)(param_1 + 0x24) != '\0') {
    if (*(float *)(param_1 + 0x234) < _DAT_005217cc !=
        (NAN(*(float *)(param_1 + 0x234)) || NAN(_DAT_005217cc))) {
      *(undefined4 *)(param_1 + 0x10) = *(undefined4 *)(param_1 + 0xc);
    }
    FUN_0044c6a0();
    return;
  }
  return;
}

