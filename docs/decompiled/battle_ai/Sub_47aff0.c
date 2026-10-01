
undefined4 FUN_0047aff0(int param_1,int param_2)

{
  if ((param_1 != 0) && (param_2 != 0)) {
    if (param_1 == param_2) {
      return 1;
    }
    if (param_1 == 5) {
      if (param_2 == 0xf) {
        return 1;
      }
    }
    else if (param_1 == 0xf) {
      if (param_2 == 5) {
        return 1;
      }
    }
    else if ((((param_1 == 8) || (param_1 == 9)) || (param_1 == 10)) ||
            (((param_1 == 0xb || (param_1 == 0xc)) || ((param_1 == 0xd || (param_1 == 0xe)))))) {
      if (param_2 == 1) {
        return 1;
      }
      if (param_2 == 2) {
        return 1;
      }
      if (param_2 == 3) {
        return 1;
      }
      if (param_2 == 4) {
        return 1;
      }
    }
    if ((((param_2 == 8) || (param_2 == 9)) ||
        ((param_2 == 10 ||
         ((((param_2 == 0xb || (param_2 == 0xc)) || (param_2 == 0xd)) || (param_2 == 0xe)))))) &&
       ((((param_1 == 1 || (param_1 == 2)) || (param_1 == 3)) || (param_1 == 4)))) {
      return 1;
    }
  }
  return 0;
}

