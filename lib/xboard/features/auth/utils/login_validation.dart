enum LoginPasswordIssue {
  empty,
  tooShort,
}

LoginPasswordIssue? validateLoginPassword(String? password) {
  if (password == null || password.isEmpty) {
    return LoginPasswordIssue.empty;
  }
  if (password.length < 8) {
    return LoginPasswordIssue.tooShort;
  }
  return null;
}
