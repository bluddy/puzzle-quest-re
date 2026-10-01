
void * __thiscall FUN_00464690(void *param_1,byte param_2)

{
  FUN_00464420();
  if ((param_2 & 1) != 0) {
                    /* WARNING: Subroutine does not return */
    operator_delete(param_1);
  }
  return param_1;
}

