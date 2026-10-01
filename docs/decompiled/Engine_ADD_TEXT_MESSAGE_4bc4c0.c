
uint __fastcall Engine_ADD_TEXT_MESSAGE_4bc4c0(int param_1)

{
  int iVar1;
  
  if (*(int *)(param_1 + 0x28) != 0) {
    iVar1 = Engine_ADD_TEXT_MESSAGE_4bc4c0();
    return (uint)*(ushort *)(param_1 + 0xc) + iVar1;
  }
  return (uint)*(ushort *)(param_1 + 0xc);
}

