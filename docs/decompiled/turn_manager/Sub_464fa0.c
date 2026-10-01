
void FUN_00464fa0(void)

{
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> local_50 [28];
  undefined **appuStack_34 [3];
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> abStack_28 [28];
  void *pvStack_c;
  undefined1 *puStack_8;
  int iStack_4;
  
  iStack_4 = 0xffffffff;
  puStack_8 = &LAB_00514332;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  std::basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>::
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>
            (local_50,"vector<T> too long");
  iStack_4 = 0;
  exception::exception((exception *)appuStack_34);
  iStack_4._0_1_ = 1;
  appuStack_34[0] = &PTR_FUN_0051a530;
  std::basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>::
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>(abStack_28,local_50);
  iStack_4 = (uint)iStack_4._1_3_ << 8;
  appuStack_34[0] = &PTR_FUN_0051a53c;
                    /* WARNING: Subroutine does not return */
  _CxxThrowException(appuStack_34,(ThrowInfo *)&DAT_005694f0);
}

