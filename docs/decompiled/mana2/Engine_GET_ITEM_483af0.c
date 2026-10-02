
void Engine_GET_ITEM_483af0(undefined4 param_1)

{
  int iVar1;
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> local_1c [28];
  
  iVar1 = Engine_GET_CHARACTER_ID_4bec10(local_1c);
  if (*(uint *)(iVar1 + 0x18) < 0x10) {
    iVar1 = iVar1 + 4;
  }
  else {
    iVar1 = *(int *)(iVar1 + 4);
  }
  FUN_004f7090(param_1,iVar1);
  std::basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>::
  ~basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>(local_1c);
  return;
}

