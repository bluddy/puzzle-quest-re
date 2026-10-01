
void Lua_GET_MOUNT(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  int *piVar3;
  char *pcVar4;
  byte bStack_6e;
  byte bStack_6d;
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> local_54 [28];
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> local_38 [28];
  ushort local_1c;
  ushort local_1a;
  ushort local_18;
  ushort local_16;
  undefined2 local_14;
  undefined4 local_10;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515d90;
  local_c = ExceptionList;
  local_10 = DAT_0057faa0;
  ExceptionList = &local_c;
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "GET_MOUNT: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_MOUNT: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    goto LAB_00494d00;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  Engine_ADD_GOLD_447c60(uVar2);
  piVar3 = (int *)Engine_ADD_GOLD_446200(uVar2);
  if ((char)piVar3[4] == '\0') {
LAB_00494ca2:
    Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
    local_4 = 1;
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
  }
  else {
    iVar1 = *(int *)(*piVar3 + 0x1b4);
    if (iVar1 < 0) goto LAB_00494ca2;
    iVar1 = *(int *)(*(int *)(*piVar3 + 0x148) + iVar1 * 6);
    if (iVar1 == 0) goto LAB_00494ca2;
    local_1c = (ushort)iVar1 & 0xff;
    bStack_6e = (byte)((uint)iVar1 >> 0x10);
    bStack_6d = (byte)((uint)iVar1 >> 0x18);
    local_1a = (ushort)(byte)((uint)iVar1 >> 8);
    local_16 = (ushort)bStack_6d;
    local_18 = (ushort)bStack_6e;
    local_14 = 0;
    Engine_ACTIVATE_COMPANION_4be530(&local_1c,0xffffffff);
    local_4 = 0;
    iVar1 = Engine_GET_CHARACTER_ID_4bec10(local_54);
    if (*(uint *)(iVar1 + 0x18) < 0x10) {
      iVar1 = iVar1 + 4;
    }
    else {
      iVar1 = *(int *)(iVar1 + 4);
    }
    FUN_004f7090(param_1,iVar1);
    std::basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>::
    ~basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>(local_54);
  }
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
LAB_00494d00:
  ExceptionList = local_c;
  FUN_005042e3();
  return;
}

