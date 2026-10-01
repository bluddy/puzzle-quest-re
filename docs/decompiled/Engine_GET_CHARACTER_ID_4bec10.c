
void __thiscall
Engine_GET_CHARACTER_ID_4bec10
          (int *param_1,
          basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> *param_2)

{
  undefined4 uVar1;
  undefined1 auStack_30 [4];
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> local_2c [28];
  void *local_10;
  void *pvStack_c;
  undefined1 *puStack_8;
  uint uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_00517893;
  pvStack_c = ExceptionList;
  local_10 = DAT_0057faa0;
  ExceptionList = &pvStack_c;
  std::basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>::
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>(local_2c);
  uStack_4 = 1;
  FUN_004be820(auStack_30,*param_1,*param_1 + param_1[2] * 2,local_2c);
  std::basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>::
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>(param_2,local_2c);
  uVar1 = 1;
  uStack_4 = uStack_4 & 0xffffff00;
  std::basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>::
  ~basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>(local_2c);
  ExceptionList = pvStack_c;
  FUN_005042e3(uVar1);
  return;
}

