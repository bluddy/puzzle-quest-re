
void Lua_GET_CURRENT_RUNE_CODE(undefined4 param_1)

{
  int iVar1;
  int iVar2;
  undefined4 uVar3;
  char *pcVar4;
  byte bStack_3e;
  byte bStack_3d;
  ushort local_3c [2];
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> local_38 [28];
  ushort local_1c;
  ushort local_1a [5];
  undefined4 local_10;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515dd8;
  local_c = ExceptionList;
  local_10 = DAT_0057faa0;
  ExceptionList = &local_c;
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "GET_CURRENT_RUNE_CODE: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_CURRENT_RUNE_CODE: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
  }
  else {
    FUN_004f6db0(param_1,1);
    iVar1 = FUN_0050432c();
    iVar2 = FUN_0044f8e0();
    if ((*(int *)(iVar2 + 0x5c) == 0) || (*(int *)(iVar2 + 0x60) - *(int *)(iVar2 + 0x5c) >> 2 == 0)
       ) {
      uVar3 = 0;
    }
    else {
      uVar3 = *(undefined4 *)(*(int *)(iVar2 + 0x60) + -4);
    }
    local_1c = (ushort)uVar3 & 0xff;
    bStack_3e = (byte)((uint)uVar3 >> 0x10);
    bStack_3d = (byte)((uint)uVar3 >> 0x18);
    local_1a[1] = (ushort)bStack_3e;
    local_1a[2] = (ushort)bStack_3d;
    local_1a[0] = (ushort)(byte)((uint)uVar3 >> 8);
    local_1a[3] = 0;
    local_3c[0] = local_1a[iVar1];
    local_3c[1] = 0;
    Engine_ACTIVATE_COMPANION_4be530(local_3c,0xffffffff);
    local_4 = 0;
    iVar1 = Engine_GET_CHARACTER_ID_4bec10(local_38);
    if (*(uint *)(iVar1 + 0x18) < 0x10) {
      iVar1 = iVar1 + 4;
    }
    else {
      iVar1 = *(int *)(iVar1 + 4);
    }
    FUN_004f7090(param_1,iVar1);
    std::basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>::
    ~basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>(local_38);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  ExceptionList = local_c;
  FUN_005042e3();
  return;
}

