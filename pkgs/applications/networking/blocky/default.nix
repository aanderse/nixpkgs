{ buildGo117Module, fetchFromGitHub }:

buildGo117Module rec {
  pname = "blocky";
  version = "0.17";

  src = fetchFromGitHub {
    owner = "0xERR0R";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-vG6QAI8gBI2nLRQ0nOFWQHihyzgmJu69rgkWlg3iW3E=";
  };

  # needs network connection and fails at
  # https://github.com/0xERR0R/blocky/blob/development/resolver/upstream_resolver_test.go
  doCheck = false;

  vendorSha256 = "sha256-my+yxDgKxoQvNhQ13T5m9pCWAIOUkdQixvKEZIaCMo0=";
}
